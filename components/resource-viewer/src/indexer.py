#!/usr/bin/env python3
"""
NubiferOS Resource Viewer - AWS resource indexer

Fetches an inventory of AWS resources via boto3 and stores metadata in the
local SQLite database (see db.py). Designed to be called from a GTK worker
thread via ResourceIndexer.sync(progress_callback), or from the command
line for headless syncs.

Credential handling:
- Uses the default boto3 credential chain ONLY. On NubiferOS, credentials
  are injected by the credential manager via `credential_process`, so a
  plain boto3.Session() picks up the active workspace's credentials.
- This module NEVER reads key files or environment variables itself and
  never writes credentials anywhere.

All AWS calls are read-only (Describe*/List*/Get*). A minimal IAM policy
for the indexer is documented in the component README.

Error handling:
- Each service (and each region within a service) is synced independently.
  Missing permissions on one service degrade the result for that service
  only; the rest of the sync completes and the failure is recorded in the
  last_sync table so the UI can surface it honestly.
"""

import argparse
import sys
from datetime import datetime, timezone

try:
    import boto3
except ImportError:  # Allows tests to run with a stubbed session
    boto3 = None

from db import ResourceDB, utc_now_iso

PROVIDER = "aws"

# Services indexed, in sync order. S3 is a global service (one listing).
SERVICES = ["ec2", "s3", "lambda", "rds", "vpc"]
GLOBAL_SERVICES = {"s3"}

FALLBACK_REGION = "us-east-1"


class IndexerError(Exception):
    """Raised for unrecoverable indexer problems (e.g. boto3 missing)."""


class ResourceIndexer:
    """Indexes AWS resources into the local resource database."""

    def __init__(self, db=None, session=None):
        """
        Args:
            db: ResourceDB instance (default: standard database path).
            session: boto3 Session (default: boto3.Session(), which uses
                the ambient credential chain). Injectable for testing.
        """
        self.db = db or ResourceDB()
        self._session = session

    # ------------------------------------------------------------------
    # Session / account / regions
    # ------------------------------------------------------------------

    @property
    def session(self):
        if self._session is None:
            if boto3 is None:
                raise IndexerError(
                    "boto3 is not installed. Install with: "
                    "pip3 install -r requirements.txt"
                )
            self._session = boto3.Session()
        return self._session

    def get_account(self):
        """Account ID from STS for the active credential chain.

        Returns '' if STS is unreachable (sync still proceeds; resources
        are recorded without an account scope).
        """
        try:
            sts = self.session.client("sts")
            return sts.get_caller_identity().get("Account", "")
        except Exception:
            return ""

    def discover_regions(self):
        """Regions enabled for the active session.

        Prefers ec2:DescribeRegions (respects opt-in status). Falls back
        to the session's configured region, then to us-east-1, so a sync
        is always possible even without ec2:DescribeRegions permission.
        """
        default = self.session.region_name or FALLBACK_REGION
        try:
            ec2 = self.session.client("ec2", region_name=default)
            resp = ec2.describe_regions(
                Filters=[{
                    "Name": "opt-in-status",
                    "Values": ["opt-in-not-required", "opted-in"],
                }]
            )
            regions = sorted(r["RegionName"] for r in resp.get("Regions", []))
            if regions:
                return regions
        except Exception:
            pass
        return [default]

    # ------------------------------------------------------------------
    # Sync entry point
    # ------------------------------------------------------------------

    def sync(self, progress_callback=None, regions=None):
        """Run a full inventory sync.

        Args:
            progress_callback: optional callable(message: str,
                fraction: float). Called from the invoking thread; a GTK
                UI should wrap UI updates in GLib.idle_add.
            regions: optional explicit region list; default is
                discover_regions().

        Returns a summary dict:
            {account, regions, started_at, finished_at,
             services: {name: {status, count, error}}}
        """
        def report(message, fraction):
            if progress_callback is not None:
                progress_callback(message, fraction)

        run_ts = utc_now_iso()
        report("Resolving account and regions...", 0.0)
        account = self.get_account()
        regions = list(regions) if regions else self.discover_regions()

        # Build the flat task list up front so progress is meaningful
        tasks = []
        for service in SERVICES:
            if service in GLOBAL_SERVICES:
                tasks.append((service, None))
            else:
                tasks.extend((service, region) for region in regions)

        summary = {
            "account": account,
            "regions": regions,
            "started_at": run_ts,
            "services": {},
        }
        results = {s: {"count": 0, "errors": [], "attempts": 0}
                   for s in SERVICES}

        collectors = {
            "ec2": self._collect_ec2,
            "s3": self._collect_s3,
            "lambda": self._collect_lambda,
            "rds": self._collect_rds,
            "vpc": self._collect_vpc,
        }

        total = len(tasks)
        for index, (service, region) in enumerate(tasks):
            label = f"{service} ({region})" if region else service
            report(f"Syncing {label}...", index / total)
            result = results[service]
            result["attempts"] += 1
            try:
                rows = collectors[service](account, region)
                self.db.upsert_resources(rows, synced_at=run_ts)
                # Remove resources that disappeared since the last sync.
                # Only done on success, and only within this account (and
                # region, for regional services), so a failed or partial
                # sync never silently drops inventory.
                self.db.delete_stale(service, account, run_ts, region=region)
                result["count"] += len(rows)
            except Exception as exc:  # isolate per service/region
                result["errors"].append(f"{region or 'global'}: {exc}")

        for service in SERVICES:
            result = results[service]
            if not result["errors"]:
                status = "ok"
            elif result["errors"] and len(result["errors"]) < result["attempts"]:
                status = "partial"
            else:
                status = "error"
            error_text = "; ".join(result["errors"])
            self.db.record_sync(service, status, result["count"], error_text,
                                synced_at=run_ts)
            summary["services"][service] = {
                "status": status,
                "count": result["count"],
                "error": error_text,
            }

        summary["finished_at"] = utc_now_iso()
        report("Sync complete", 1.0)
        return summary

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _make_id(account, region, native_id):
        """Stable primary key: unique across accounts and regions."""
        return f"{PROVIDER}:{account}:{region}:{native_id}"

    @staticmethod
    def _tag_name(tags, fallback):
        for tag in tags or []:
            if tag.get("Key") == "Name" and tag.get("Value"):
                return tag["Value"]
        return fallback

    def _row(self, account, region, service, rtype, native_id, name, props):
        return {
            "id": self._make_id(account, region, native_id),
            "provider": PROVIDER,
            "account": account,
            "region": region,
            "service": service,
            "type": rtype,
            "name": name,
            "properties": props,
        }

    # ------------------------------------------------------------------
    # Per-service collectors (all read-only API calls)
    # ------------------------------------------------------------------

    def _collect_ec2(self, account, region):
        client = self.session.client("ec2", region_name=region)
        rows = []
        paginator = client.get_paginator("describe_instances")
        for page in paginator.paginate():
            for reservation in page.get("Reservations", []):
                for instance in reservation.get("Instances", []):
                    iid = instance["InstanceId"]
                    rows.append(self._row(
                        account, region, "ec2", "instance", iid,
                        self._tag_name(instance.get("Tags"), iid),
                        instance,
                    ))
        return rows

    def _collect_s3(self, account, region=None):
        # S3 listing is global; each bucket's home region is resolved
        # individually (get_bucket_location may fail per bucket without
        # aborting the listing).
        client = self.session.client("s3")
        rows = []
        for bucket in client.list_buckets().get("Buckets", []):
            name = bucket["Name"]
            bucket_region = "unknown"
            try:
                loc = client.get_bucket_location(Bucket=name)
                constraint = loc.get("LocationConstraint")
                # Legacy API quirks: None means us-east-1, "EU" means
                # eu-west-1
                if constraint is None:
                    bucket_region = "us-east-1"
                elif constraint == "EU":
                    bucket_region = "eu-west-1"
                else:
                    bucket_region = constraint
            except Exception:
                pass
            rows.append(self._row(
                account, bucket_region, "s3", "bucket", name, name, bucket,
            ))
        return rows

    def _collect_lambda(self, account, region):
        client = self.session.client("lambda", region_name=region)
        rows = []
        paginator = client.get_paginator("list_functions")
        for page in paginator.paginate():
            for function in page.get("Functions", []):
                fname = function["FunctionName"]
                rows.append(self._row(
                    account, region, "lambda", "function", fname, fname,
                    function,
                ))
        return rows

    def _collect_rds(self, account, region):
        client = self.session.client("rds", region_name=region)
        rows = []
        paginator = client.get_paginator("describe_db_instances")
        for page in paginator.paginate():
            for db_instance in page.get("DBInstances", []):
                identifier = db_instance["DBInstanceIdentifier"]
                rows.append(self._row(
                    account, region, "rds", "db-instance", identifier,
                    identifier, db_instance,
                ))
        return rows

    def _collect_vpc(self, account, region):
        client = self.session.client("ec2", region_name=region)
        rows = []

        for page in client.get_paginator("describe_vpcs").paginate():
            for vpc in page.get("Vpcs", []):
                vid = vpc["VpcId"]
                rows.append(self._row(
                    account, region, "vpc", "vpc", vid,
                    self._tag_name(vpc.get("Tags"), vid), vpc,
                ))

        for page in client.get_paginator("describe_subnets").paginate():
            for subnet in page.get("Subnets", []):
                sid = subnet["SubnetId"]
                rows.append(self._row(
                    account, region, "vpc", "subnet", sid,
                    self._tag_name(subnet.get("Tags"), sid), subnet,
                ))

        for page in client.get_paginator("describe_security_groups").paginate():
            for group in page.get("SecurityGroups", []):
                gid = group["GroupId"]
                rows.append(self._row(
                    account, region, "vpc", "security-group", gid,
                    group.get("GroupName") or gid, group,
                ))

        return rows


# ----------------------------------------------------------------------
# CLI entry point (headless sync)
# ----------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Sync AWS resource inventory to the local database"
    )
    parser.add_argument(
        "--db", default=None,
        help="Database path (default: ~/.local/share/nubifer/resources.db)",
    )
    parser.add_argument(
        "--regions", default=None,
        help="Comma-separated region list (default: regions enabled for "
             "the active session)",
    )
    args = parser.parse_args(argv)

    regions = None
    if args.regions:
        regions = [r.strip() for r in args.regions.split(",") if r.strip()]

    def progress(message, fraction):
        print(f"[{int(fraction * 100):3d}%] {message}")

    indexer = ResourceIndexer(db=ResourceDB(args.db) if args.db else None)
    try:
        summary = indexer.sync(progress_callback=progress, regions=regions)
    except IndexerError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print()
    print(f"Account: {summary['account'] or '(unknown)'}")
    print(f"Regions: {', '.join(summary['regions'])}")
    failed = False
    for service, result in summary["services"].items():
        line = f"  {service:8s} {result['status']:8s} {result['count']} resources"
        if result["error"]:
            line += f"  ({result['error']})"
            failed = failed or result["status"] == "error"
        print(line)
    return 0 if not failed else 2


if __name__ == "__main__":
    sys.exit(main())
