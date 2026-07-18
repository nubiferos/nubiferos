#!/usr/bin/env python3
"""
Unit tests for the Resource Viewer indexer and database layer.

boto3 is fully stubbed via unittest.mock - no network, no real
credentials, no moto. The indexer accepts an injected session object,
so these tests run even on machines without boto3 installed.
"""

import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock

# Add src to path
sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src"))

from db import ResourceDB
from indexer import ResourceIndexer

ACCOUNT = "123456789012"


# ----------------------------------------------------------------------
# Fake boto3 session helpers
# ----------------------------------------------------------------------

def make_paginator(pages):
    paginator = MagicMock()
    paginator.paginate.return_value = pages
    return paginator


def make_ec2_client(instances=None, vpcs=None, subnets=None, groups=None,
                    regions=("us-east-1",)):
    client = MagicMock()
    paginators = {
        "describe_instances": make_paginator(
            [{"Reservations": [{"Instances": instances or []}]}]),
        "describe_vpcs": make_paginator([{"Vpcs": vpcs or []}]),
        "describe_subnets": make_paginator([{"Subnets": subnets or []}]),
        "describe_security_groups": make_paginator(
            [{"SecurityGroups": groups or []}]),
    }
    client.get_paginator.side_effect = lambda op: paginators[op]
    client.describe_regions.return_value = {
        "Regions": [{"RegionName": r} for r in regions]}
    return client


def make_sts_client(account=ACCOUNT):
    client = MagicMock()
    client.get_caller_identity.return_value = {"Account": account}
    return client


def make_s3_client(buckets=None, location="us-east-2"):
    client = MagicMock()
    client.list_buckets.return_value = {
        "Buckets": [{"Name": b} for b in (buckets or [])]}
    client.get_bucket_location.return_value = {
        "LocationConstraint": location}
    return client


def make_lambda_client(functions=None):
    client = MagicMock()
    client.get_paginator.return_value = make_paginator(
        [{"Functions": [{"FunctionName": f} for f in (functions or [])]}])
    return client


def make_rds_client(identifiers=None):
    client = MagicMock()
    client.get_paginator.return_value = make_paginator(
        [{"DBInstances": [{"DBInstanceIdentifier": i}
                          for i in (identifiers or [])]}])
    return client


class FakeSession:
    """Stands in for boto3.Session; hands out preconfigured mock clients."""

    def __init__(self, clients, region_name="us-east-1"):
        self._clients = clients
        self.region_name = region_name

    def client(self, name, **kwargs):
        return self._clients[name]


def make_default_session(**overrides):
    clients = {
        "sts": make_sts_client(),
        "ec2": make_ec2_client(
            instances=[{
                "InstanceId": "i-0abc123",
                "InstanceType": "t3.micro",
                "Tags": [{"Key": "Name", "Value": "web-server"}],
            }],
            vpcs=[{"VpcId": "vpc-111",
                   "Tags": [{"Key": "Name", "Value": "main-vpc"}]}],
            subnets=[{"SubnetId": "subnet-222"}],
            groups=[{"GroupId": "sg-333", "GroupName": "default"}],
        ),
        "s3": make_s3_client(buckets=["my-data-bucket"]),
        "lambda": make_lambda_client(functions=["process-events"]),
        "rds": make_rds_client(identifiers=["prod-postgres"]),
    }
    clients.update(overrides)
    return FakeSession(clients)


# ----------------------------------------------------------------------
# Database layer tests
# ----------------------------------------------------------------------

class TestResourceDB(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "resources.db"
        self.db = ResourceDB(db_path=self.db_path)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _row(self, rid="aws:123:us-east-1:i-1", **kwargs):
        row = {
            "id": rid,
            "provider": "aws",
            "account": ACCOUNT,
            "region": "us-east-1",
            "service": "ec2",
            "type": "instance",
            "name": "web-server",
            "properties": {"InstanceType": "t3.micro"},
        }
        row.update(kwargs)
        return row

    def test_schema_creation(self):
        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        tables = {r[0] for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")}
        conn.close()
        self.assertIn("resources", tables)
        self.assertIn("last_sync", tables)

    def test_upsert_inserts_and_updates(self):
        self.db.upsert_resources([self._row()])
        self.assertEqual(len(self.db.list_resources()), 1)

        # Same id again with new name: must update, not duplicate
        self.db.upsert_resources([self._row(name="renamed-server")])
        rows = self.db.list_resources()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["name"], "renamed-server")

    def test_get_resource_parses_properties(self):
        self.db.upsert_resources([self._row()])
        resource = self.db.get_resource("aws:123:us-east-1:i-1")
        self.assertIsNotNone(resource)
        self.assertEqual(resource["properties"]["InstanceType"], "t3.micro")
        self.assertIsNone(self.db.get_resource("does-not-exist"))

    def test_list_services_counts(self):
        self.db.upsert_resources([
            self._row("a:1"), self._row("a:2"),
            self._row("b:1", service="s3", type="bucket"),
        ])
        services = {s["service"]: s["resource_count"]
                    for s in self.db.list_services()}
        self.assertEqual(services, {"ec2": 2, "s3": 1})

    def test_list_resources_filters(self):
        self.db.upsert_resources([
            self._row("a:1"),
            self._row("a:2", region="eu-west-1"),
            self._row("b:1", service="s3", type="bucket"),
        ])
        self.assertEqual(len(self.db.list_resources(service="ec2")), 2)
        self.assertEqual(len(self.db.list_resources(region="eu-west-1")), 1)
        self.assertEqual(
            len(self.db.list_resources(service="ec2", region="eu-west-1")), 1)

    def test_search_by_name_id_and_type(self):
        self.db.upsert_resources([
            self._row("aws:123:us-east-1:i-0deadbeef", name="api-server"),
            self._row("b:1", service="s3", type="bucket", name="logs"),
        ])
        # By name substring
        self.assertEqual(len(self.db.search("api")), 1)
        # By id substring
        self.assertEqual(len(self.db.search("i-0deadbeef")), 1)
        # By type
        self.assertEqual(len(self.db.search("bucket")), 1)
        # No match
        self.assertEqual(self.db.search("zzz-nothing"), [])
        # Empty term returns nothing rather than everything
        self.assertEqual(self.db.search(""), [])

    def test_search_escapes_like_wildcards(self):
        self.db.upsert_resources([self._row(name="prod")])
        # "%" must not act as match-everything
        self.assertEqual(self.db.search("%"), [])

    def test_delete_stale_scoped_to_account(self):
        self.db.upsert_resources([self._row("old:1")],
                                 synced_at="2026-01-01T00:00:00+00:00")
        self.db.upsert_resources(
            [self._row("other:1", account="999999999999")],
            synced_at="2026-01-01T00:00:00+00:00")
        deleted = self.db.delete_stale("ec2", ACCOUNT,
                                       "2026-02-01T00:00:00+00:00",
                                       region="us-east-1")
        self.assertEqual(deleted, 1)
        # The other account's resource survives
        self.assertIsNotNone(self.db.get_resource("other:1"))

    def test_record_and_get_sync_status(self):
        self.db.record_sync("ec2", "ok", 5)
        self.db.record_sync("lambda", "error", 0, "AccessDenied")
        status = self.db.get_sync_status()
        self.assertEqual(status["ec2"]["status"], "ok")
        self.assertEqual(status["ec2"]["resource_count"], 5)
        self.assertEqual(status["lambda"]["status"], "error")
        self.assertIn("AccessDenied", status["lambda"]["error"])
        # Re-recording updates rather than duplicates
        self.db.record_sync("ec2", "ok", 7)
        self.assertEqual(self.db.get_sync_status()["ec2"]["resource_count"], 7)


# ----------------------------------------------------------------------
# Indexer tests
# ----------------------------------------------------------------------

class TestResourceIndexer(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.db = ResourceDB(db_path=Path(self.temp_dir) / "resources.db")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_full_sync_populates_all_services(self):
        indexer = ResourceIndexer(db=self.db, session=make_default_session())
        summary = indexer.sync()

        self.assertEqual(summary["account"], ACCOUNT)
        for service in ("ec2", "s3", "lambda", "rds", "vpc"):
            self.assertEqual(summary["services"][service]["status"], "ok",
                             f"{service} should sync cleanly")

        services = {s["service"]: s["resource_count"]
                    for s in self.db.list_services()}
        self.assertEqual(services["ec2"], 1)      # instance
        self.assertEqual(services["s3"], 1)       # bucket
        self.assertEqual(services["lambda"], 1)   # function
        self.assertEqual(services["rds"], 1)      # db instance
        self.assertEqual(services["vpc"], 3)      # vpc + subnet + sg

        # Name tag extraction and detail retrieval
        results = self.db.search("web-server")
        self.assertEqual(len(results), 1)
        detail = self.db.get_resource(results[0]["id"])
        self.assertEqual(detail["properties"]["InstanceId"], "i-0abc123")
        self.assertEqual(detail["account"], ACCOUNT)

    def test_service_error_does_not_abort_sync(self):
        broken_lambda = MagicMock()
        broken_lambda.get_paginator.side_effect = Exception(
            "AccessDenied: not authorized to perform lambda:ListFunctions")
        session = make_default_session(**{"lambda": broken_lambda})

        indexer = ResourceIndexer(db=self.db, session=session)
        summary = indexer.sync()

        # Lambda failed...
        self.assertEqual(summary["services"]["lambda"]["status"], "error")
        self.assertIn("AccessDenied", summary["services"]["lambda"]["error"])
        # ...but every other service completed
        for service in ("ec2", "s3", "rds", "vpc"):
            self.assertEqual(summary["services"][service]["status"], "ok")
        self.assertEqual(len(self.db.list_resources(service="ec2")), 1)
        self.assertEqual(len(self.db.list_resources(service="lambda")), 0)

        # Failure is recorded in last_sync for the UI
        status = self.db.get_sync_status()
        self.assertEqual(status["lambda"]["status"], "error")
        self.assertIn("AccessDenied", status["lambda"]["error"])

    def test_sync_removes_stale_resources_on_success(self):
        # A resource that no longer exists in AWS, same account/region
        self.db.upsert_resources([{
            "id": "aws:123456789012:us-east-1:i-gone",
            "provider": "aws", "account": ACCOUNT, "region": "us-east-1",
            "service": "ec2", "type": "instance", "name": "terminated",
            "properties": {},
        }], synced_at="2026-01-01T00:00:00+00:00")

        indexer = ResourceIndexer(db=self.db, session=make_default_session())
        indexer.sync()

        ids = {r["id"] for r in self.db.list_resources(service="ec2")}
        self.assertNotIn("aws:123456789012:us-east-1:i-gone", ids)
        self.assertEqual(len(ids), 1)  # only the live instance remains

    def test_failed_service_keeps_previous_inventory(self):
        # Existing lambda inventory must survive a failed lambda sync
        self.db.upsert_resources([{
            "id": "aws:123456789012:us-east-1:old-func",
            "provider": "aws", "account": ACCOUNT, "region": "us-east-1",
            "service": "lambda", "type": "function", "name": "old-func",
            "properties": {},
        }], synced_at="2026-01-01T00:00:00+00:00")

        broken_lambda = MagicMock()
        broken_lambda.get_paginator.side_effect = Exception("Throttled")
        session = make_default_session(**{"lambda": broken_lambda})
        ResourceIndexer(db=self.db, session=session).sync()

        self.assertIsNotNone(
            self.db.get_resource("aws:123456789012:us-east-1:old-func"))

    def test_discover_regions_from_session(self):
        session = make_default_session(
            ec2=make_ec2_client(regions=("eu-west-1", "us-east-1")))
        indexer = ResourceIndexer(db=self.db, session=session)
        self.assertEqual(indexer.discover_regions(),
                         ["eu-west-1", "us-east-1"])

    def test_discover_regions_falls_back_to_session_region(self):
        broken_ec2 = MagicMock()
        broken_ec2.describe_regions.side_effect = Exception("AccessDenied")
        session = FakeSession({"ec2": broken_ec2}, region_name="ap-south-1")
        indexer = ResourceIndexer(db=self.db, session=session)
        self.assertEqual(indexer.discover_regions(), ["ap-south-1"])

    def test_sync_with_explicit_regions_syncs_each_region(self):
        session = make_default_session()
        indexer = ResourceIndexer(db=self.db, session=session)
        summary = indexer.sync(regions=["us-east-1", "eu-west-1"])
        self.assertEqual(summary["regions"], ["us-east-1", "eu-west-1"])
        # Same fake data in both regions -> distinct composite ids
        self.assertEqual(len(self.db.list_resources(service="ec2")), 2)

    def test_progress_callback_invoked(self):
        events = []
        indexer = ResourceIndexer(db=self.db, session=make_default_session())
        indexer.sync(progress_callback=lambda msg, frac: events.append((msg, frac)))
        self.assertGreater(len(events), 2)
        self.assertEqual(events[-1], ("Sync complete", 1.0))
        fractions = [f for _, f in events]
        self.assertEqual(fractions, sorted(fractions))  # monotonic

    def test_account_failure_does_not_abort_sync(self):
        broken_sts = MagicMock()
        broken_sts.get_caller_identity.side_effect = Exception("NoCredentials")
        session = make_default_session(sts=broken_sts)
        summary = ResourceIndexer(db=self.db, session=session).sync()
        self.assertEqual(summary["account"], "")
        self.assertEqual(summary["services"]["ec2"]["status"], "ok")

    def test_properties_stored_as_json(self):
        indexer = ResourceIndexer(db=self.db, session=make_default_session())
        indexer.sync()
        bucket = self.db.search("my-data-bucket")[0]
        detail = self.db.get_resource(bucket["id"])
        self.assertIsInstance(detail["properties"], dict)
        self.assertEqual(detail["properties"]["Name"], "my-data-bucket")
        # Bucket region resolved via get_bucket_location
        self.assertEqual(detail["region"], "us-east-2")


if __name__ == "__main__":
    unittest.main()
