-- NubiferOS CLI Audit Trail Schema
-- Local command history for cloud CLI operations

CREATE TABLE IF NOT EXISTS command_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')),
    user TEXT NOT NULL,
    workspace_id TEXT,
    workspace_name TEXT,
    provider TEXT NOT NULL,
    cloud_account TEXT,
    command TEXT NOT NULL,
    args TEXT,
    read_only INTEGER,
    outcome TEXT NOT NULL,
    credential_hint TEXT,
    credential_name TEXT,
    session_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON command_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_workspace ON command_log(workspace_id);
CREATE INDEX IF NOT EXISTS idx_provider ON command_log(provider);
CREATE INDEX IF NOT EXISTS idx_outcome ON command_log(outcome);
