#!/usr/bin/env python3
"""
NubiferOS Resource Viewer - SQLite storage layer

Stores an inventory of cloud resources (metadata only, never secrets) in a
local SQLite database. Provides a read-only query API for the GTK UI and a
write API for the indexer.

Database location: ~/.local/share/nubifer/resources.db

Security notes:
- Only resource *metadata* is stored (IDs, names, tags, configuration
  properties as returned by describe/list APIs). No credentials, no key
  material.
- The database file and its parent directory are created with restrictive
  permissions (0600 / 0700). Resource metadata can still reveal account
  topology, so treat the file as sensitive.
"""

import json
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_DB_PATH = Path.home() / ".local" / "share" / "nubifer" / "resources.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS resources (
    id          TEXT PRIMARY KEY,
    provider    TEXT NOT NULL,
    account     TEXT NOT NULL DEFAULT '',
    region      TEXT NOT NULL DEFAULT '',
    service     TEXT NOT NULL,
    type        TEXT NOT NULL,
    name        TEXT NOT NULL DEFAULT '',
    properties  TEXT NOT NULL DEFAULT '{}',
    synced_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_resources_service ON resources(service);
CREATE INDEX IF NOT EXISTS idx_resources_name    ON resources(name);
CREATE INDEX IF NOT EXISTS idx_resources_region  ON resources(region);

CREATE TABLE IF NOT EXISTS last_sync (
    service        TEXT PRIMARY KEY,
    status         TEXT NOT NULL,
    resource_count INTEGER NOT NULL DEFAULT 0,
    error          TEXT NOT NULL DEFAULT '',
    synced_at      TEXT NOT NULL
);
"""


def utc_now_iso():
    """Current UTC time as ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


class ResourceDB:
    """SQLite-backed resource inventory.

    Thread note: each public method opens its own connection, so instances
    are safe to share between the GTK main loop and an indexer worker
    thread (SQLite serializes writers; readers see committed data).
    """

    def __init__(self, db_path=None):
        self.db_path = Path(db_path) if db_path else DEFAULT_DB_PATH
        self._init_db()

    # ------------------------------------------------------------------
    # Setup
    # ------------------------------------------------------------------

    def _init_db(self):
        parent = self.db_path.parent
        parent.mkdir(parents=True, exist_ok=True)
        try:
            os.chmod(parent, 0o700)
        except OSError:
            pass  # e.g. parent owned by another user in tests

        with self._connect() as conn:
            conn.executescript(SCHEMA)

        try:
            os.chmod(self.db_path, 0o600)
        except OSError:
            pass

    def _connect(self):
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        return conn

    # ------------------------------------------------------------------
    # Write API (used by the indexer)
    # ------------------------------------------------------------------

    def upsert_resources(self, rows, synced_at=None):
        """Insert or update resource rows.

        Each row is a dict with keys: id, provider, account, region,
        service, type, name, properties (dict or JSON string).
        Returns the number of rows written.
        """
        if not rows:
            return 0
        synced_at = synced_at or utc_now_iso()

        prepared = []
        for row in rows:
            props = row.get("properties", {})
            if not isinstance(props, str):
                # default=str handles datetimes returned by cloud SDKs
                props = json.dumps(props, default=str)
            prepared.append((
                row["id"],
                row.get("provider", "aws"),
                row.get("account", ""),
                row.get("region", ""),
                row["service"],
                row.get("type", ""),
                row.get("name", ""),
                props,
                synced_at,
            ))

        with self._connect() as conn:
            conn.executemany(
                """
                INSERT INTO resources
                    (id, provider, account, region, service, type, name,
                     properties, synced_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    provider   = excluded.provider,
                    account    = excluded.account,
                    region     = excluded.region,
                    service    = excluded.service,
                    type       = excluded.type,
                    name       = excluded.name,
                    properties = excluded.properties,
                    synced_at  = excluded.synced_at
                """,
                prepared,
            )
        return len(prepared)

    def delete_stale(self, service, account, before, region=None):
        """Delete rows for a service (optionally one region) that were not
        touched by the current sync run (synced_at < before).

        Scoped to one account so a sync in workspace A never deletes
        resources indexed from workspace B.
        Returns the number of rows deleted.
        """
        query = ("DELETE FROM resources "
                 "WHERE service = ? AND account = ? AND synced_at < ?")
        params = [service, account, before]
        if region is not None:
            query += " AND region = ?"
            params.append(region)
        with self._connect() as conn:
            cur = conn.execute(query, params)
            return cur.rowcount

    def record_sync(self, service, status, resource_count=0, error="",
                    synced_at=None):
        """Record sync metadata for a service (status: ok/partial/error)."""
        synced_at = synced_at or utc_now_iso()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO last_sync
                    (service, status, resource_count, error, synced_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(service) DO UPDATE SET
                    status         = excluded.status,
                    resource_count = excluded.resource_count,
                    error          = excluded.error,
                    synced_at      = excluded.synced_at
                """,
                (service, status, int(resource_count), error or "", synced_at),
            )

    # ------------------------------------------------------------------
    # Read API (used by the UI)
    # ------------------------------------------------------------------

    def list_services(self):
        """List indexed services with resource counts.

        Returns list of dicts: {service, resource_count}.
        """
        with self._connect() as conn:
            cur = conn.execute(
                "SELECT service, COUNT(*) AS resource_count "
                "FROM resources GROUP BY service ORDER BY service"
            )
            return [dict(r) for r in cur.fetchall()]

    def list_resources(self, service=None, region=None, resource_type=None,
                       account=None, limit=500):
        """List resources with optional filters, newest-synced first."""
        query = ("SELECT id, provider, account, region, service, type, name, "
                 "synced_at FROM resources WHERE 1=1")
        params = []
        for column, value in (("service", service), ("region", region),
                              ("type", resource_type), ("account", account)):
            if value is not None:
                query += f" AND {column} = ?"
                params.append(value)
        query += " ORDER BY service, name LIMIT ?"
        params.append(int(limit))
        with self._connect() as conn:
            cur = conn.execute(query, params)
            return [dict(r) for r in cur.fetchall()]

    def search(self, term, limit=200):
        """Case-insensitive substring search over name, id, and type."""
        if not term:
            return []
        # Escape SQLite LIKE wildcards in the user's term
        escaped = (term.replace("\\", "\\\\")
                       .replace("%", "\\%")
                       .replace("_", "\\_"))
        pattern = f"%{escaped}%"
        with self._connect() as conn:
            cur = conn.execute(
                """
                SELECT id, provider, account, region, service, type, name,
                       synced_at
                FROM resources
                WHERE name LIKE ? ESCAPE '\\'
                   OR id   LIKE ? ESCAPE '\\'
                   OR type LIKE ? ESCAPE '\\'
                ORDER BY service, name
                LIMIT ?
                """,
                (pattern, pattern, pattern, int(limit)),
            )
            return [dict(r) for r in cur.fetchall()]

    def get_resource(self, resource_id):
        """Fetch a single resource with parsed properties, or None."""
        with self._connect() as conn:
            cur = conn.execute(
                "SELECT * FROM resources WHERE id = ?", (resource_id,)
            )
            row = cur.fetchone()
        if row is None:
            return None
        result = dict(row)
        try:
            result["properties"] = json.loads(result["properties"])
        except (ValueError, TypeError):
            result["properties"] = {}
        return result

    def get_sync_status(self):
        """Return last_sync rows keyed by service."""
        with self._connect() as conn:
            cur = conn.execute("SELECT * FROM last_sync ORDER BY service")
            return {r["service"]: dict(r) for r in cur.fetchall()}
