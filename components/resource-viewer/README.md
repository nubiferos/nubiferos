# NubiferOS Resource Viewer

Local, read-only inventory of your cloud resources. Sync once, then browse
and search EC2 instances, S3 buckets, Lambda functions, RDS instances, and
VPC networking from a local SQLite database - no console tab-hopping, no
repeated API calls while you browse.

## Architecture

- **Indexer** (`src/indexer.py`): fetches AWS resources via boto3 and
  writes metadata to SQLite. Callable from a GTK worker thread
  (`ResourceIndexer.sync(progress_callback)`) or headless from the CLI.
- **Storage** (`src/db.py`): SQLite database at
  `~/.local/share/nubifer/resources.db` with a read-only query API for
  the UI (list services, list/filter resources, search, resource detail,
  sync status).
- **GUI** (`src/nubifer-resources`): GTK3 browser matching the other
  NubiferOS desktop components (security dashboard, first-boot wizard).
  Resource tree grouped provider > service > resource, live search over
  name/ID/type, detail pane with all resource properties, and a Sync
  button that runs the indexer in a background thread. The UI always
  renders from the local database, so it works fully offline - a failed
  sync keeps cached data visible and shows a dismissible warning instead
  of an empty screen.

> Note: an earlier spec called for Electron/Tauri + React + FastAPI. The
> repo has since converged on single-purpose Python GTK3 apps; this
> component follows that convention.

### Indexed services (AWS, phase 1)

| Service | Resource types |
|---------|----------------|
| ec2     | instance |
| s3      | bucket |
| lambda  | function |
| rds     | db-instance |
| vpc     | vpc, subnet, security-group |

Multi-provider support (Azure, GCP) is a future phase - the schema
already carries a `provider` column so nothing needs to migrate.

### Database schema

```sql
CREATE TABLE resources (
    id          TEXT PRIMARY KEY,   -- aws:<account>:<region>:<native-id>
    provider    TEXT NOT NULL,
    account     TEXT NOT NULL,
    region      TEXT NOT NULL,
    service     TEXT NOT NULL,
    type        TEXT NOT NULL,
    name        TEXT NOT NULL,      -- Name tag or native identifier
    properties  TEXT NOT NULL,      -- raw describe/list output as JSON
    synced_at   TEXT NOT NULL
);

CREATE TABLE last_sync (
    service        TEXT PRIMARY KEY,
    status         TEXT NOT NULL,   -- ok | partial | error
    resource_count INTEGER NOT NULL,
    error          TEXT NOT NULL,
    synced_at      TEXT NOT NULL
);
```

The composite primary key keeps IDs unique across accounts and regions,
so switching workspaces never clobbers another workspace's inventory.

## Credential handling

The indexer uses the **default boto3 credential chain only**. On
NubiferOS the credential manager injects short-lived credentials via
`credential_process`, so a plain `boto3.Session()` picks up the active
workspace automatically. The indexer never reads key files, never touches
environment variables itself, and never writes credentials anywhere.

All API calls are read-only (`Describe*` / `List*` / `Get*`). A minimal
IAM policy for a dedicated indexer role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "sts:GetCallerIdentity",
      "ec2:DescribeRegions",
      "ec2:DescribeInstances",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "lambda:ListFunctions",
      "rds:DescribeDBInstances"
    ],
    "Resource": "*"
  }]
}
```

Missing permissions degrade gracefully: a service you cannot list is
recorded as `error` in `last_sync` (with the exception text) and the
rest of the sync completes. Previously indexed inventory for a failed
service is kept, not deleted - stale rows are only pruned after a
*successful* sync of that service/region for the same account.

## Installation

```bash
cd components/resource-viewer
sudo ./install.sh
```

This installs:
- Source files to `/usr/local/lib/nubiferos/resource-viewer/`
- CLI sync tool: `/usr/local/bin/nubifer-resource-sync`
- GUI browser: `/usr/local/bin/nubifer-resources` (plus a desktop entry)

## Usage

### GUI browser

```bash
nubifer-resources
```

- **Tree pane**: resources grouped provider > service > resource.
- **Search**: filters the tree live on name, native ID, and type.
- **Sync button**: runs the indexer in a background thread with a
  progress bar; the window stays responsive throughout.
- **Detail pane**: every property from the raw describe/list output,
  pretty-printed and selectable for copy/paste.
- **Cached-data banner**: always shows when the inventory was last
  synced. If a sync fails (no network, no credentials, missing IAM
  permissions), cached data stays visible and a dismissible warning
  explains what happened - stale-but-labelled beats an empty screen.

### CLI sync

```bash
# Sync all regions enabled for the active workspace
nubifer-resource-sync

# Limit to specific regions (faster)
nubifer-resource-sync --regions us-east-1,eu-west-1

# Use an alternate database (e.g. for testing)
nubifer-resource-sync --db /tmp/test-resources.db
```

Exit codes: `0` all services synced (ok/partial), `1` unrecoverable
error (e.g. boto3 missing), `2` at least one service failed entirely.

### From Python (GUI worker thread)

```python
from indexer import ResourceIndexer
from db import ResourceDB

def on_progress(message, fraction):
    # In a GTK app, marshal back to the main loop:
    GLib.idle_add(progress_bar.set_fraction, fraction)
    GLib.idle_add(status_label.set_text, message)

indexer = ResourceIndexer()
summary = indexer.sync(progress_callback=on_progress)  # run in a thread

db = ResourceDB()
db.list_services()                 # [{"service": "ec2", "resource_count": 12}, ...]
db.list_resources(service="ec2")   # rows without properties blob
db.search("prod")                  # substring match on name/id/type
db.get_resource(resource_id)       # full detail, properties parsed to dict
db.get_sync_status()               # last_sync rows keyed by service
```

## Security notes (honest limitations)

- **Metadata is sensitive.** The database stores no secrets, but resource
  names, tags, security group rules, and network topology are valuable to
  an attacker. The file is created `0600` inside a `0700` directory, and
  full-disk encryption (standard on NubiferOS) protects it at rest -
  but any process running as your user can read it. This is inventory
  caching, not a security boundary.
- **The inventory is a snapshot.** Resources created or deleted after the
  last sync will not appear until you sync again. Check `last_sync`
  timestamps before trusting the view for anything operational.
- **Per-account scoping, not isolation.** Syncing in one workspace never
  deletes another account's rows, but all accounts share one database
  file. If you need hard separation between workspaces, use `--db` with
  per-workspace paths.
- **Read-only by construction, not enforcement.** The indexer only calls
  read APIs, but nothing stops the ambient credentials from having write
  permissions. Prefer a read-only role for routine syncing.

## Development

### Project structure

```
components/resource-viewer/
├── src/
│   ├── indexer.py           # AWS resource indexer + CLI entry point
│   ├── db.py                # SQLite storage and query API
│   └── nubifer-resources    # GTK3 browser UI
├── tests/
│   └── test_indexer.py  # Unit tests (boto3 stubbed, no network)
├── requirements.txt
├── install.sh
└── README.md
```

### Running tests

```bash
# Syntax check
python3 -m py_compile src/*.py

# Unit tests (no AWS access, no boto3 required - session is stubbed)
python3 -m unittest discover -s tests -v
# or, if pytest is installed:
python3 -m pytest tests/ -v
```

## Roadmap

- [x] AWS indexer (EC2, S3, Lambda, RDS, VPC)
- [x] SQLite storage + query API
- [x] GTK3 browser UI (service tree, search, detail pane, offline/cached indicator)
- [ ] Scheduled background sync (systemd user timer)
- [ ] Azure / GCP providers
- [ ] Relationship view (instance -> subnet -> VPC)

## License

Part of NubiferOS - GPL-3.0
