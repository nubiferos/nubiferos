#!/bin/bash
# NubiferOS CLI Audit Trail - Shared Functions
# Sourced by CLI wrappers to log all cloud commands locally
#
# Usage in wrappers:
#   source /etc/nubifer/audit-functions.sh 2>/dev/null
#   _nubifer_audit_log <provider> <outcome> "$@"

NUBIFER_AUDIT_DIR="${HOME}/.local/share/nubifer/audit"
NUBIFER_AUDIT_DB="${NUBIFER_AUDIT_DIR}/commands.db"
NUBIFER_AUDIT_SCHEMA="/etc/nubifer/audit-schema.sql"

# Initialize database if needed
_nubifer_audit_init() {
    [ -d "$NUBIFER_AUDIT_DIR" ] && [ -f "$NUBIFER_AUDIT_DB" ] && return 0

    mkdir -p "$NUBIFER_AUDIT_DIR" 2>/dev/null
    chmod 700 "$NUBIFER_AUDIT_DIR" 2>/dev/null

    if ! command -v sqlite3 &>/dev/null; then
        return 1
    fi

    if [ -f "$NUBIFER_AUDIT_SCHEMA" ]; then
        sqlite3 "$NUBIFER_AUDIT_DB" < "$NUBIFER_AUDIT_SCHEMA" 2>/dev/null
    else
        sqlite3 "$NUBIFER_AUDIT_DB" <<'SQL'
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
SQL
    fi

    chmod 600 "$NUBIFER_AUDIT_DB" 2>/dev/null
    # Enable WAL mode for concurrent writes from multiple terminals
    sqlite3 "$NUBIFER_AUDIT_DB" "PRAGMA journal_mode=WAL;" 2>/dev/null
    return 0
}

# Extract last 4 chars of the identifying credential from pass
# Usage: _nubifer_audit_get_cred_hint <provider> [cred_name]
_nubifer_audit_get_cred_hint() {
    local provider="$1"
    local cred_name="${2:-default}"
    local ws_id="$NUBIFER_WORKSPACE_ID"
    local pass_path=""
    local hint=""

    [ -z "$ws_id" ] && return

    case "$provider" in
        aws)
            pass_path="nubifer/${ws_id}/cloud/aws/${cred_name}/access-key-id"
            ;;
        azure)
            pass_path="nubifer/${ws_id}/cloud/azure/${cred_name}/client-id"
            ;;
        gcp)
            pass_path="nubifer/${ws_id}/cloud/gcp/${cred_name}/project-id"
            ;;
        oracle)
            pass_path="nubifer/${ws_id}/cloud/oci/${cred_name}/tenancy-ocid"
            ;;
        *)
            return
            ;;
    esac

    # Use NUBIFER_CRED_HINT if already set by the wrapper (avoids extra GPG decryption)
    if [ -n "${NUBIFER_CRED_HINT:-}" ]; then
        hint="$NUBIFER_CRED_HINT"
    fi

    echo "$hint"
}

# Get cloud account identifier from workspace JSON
_nubifer_audit_get_account() {
    local ws_id="$NUBIFER_WORKSPACE_ID"
    [ -z "$ws_id" ] && return

    local ws_file="${HOME}/.config/nubifer/workspaces/${ws_id}.json"
    [ -f "$ws_file" ] || return

    python3 -c "
import json
with open('${ws_file}') as f:
    ws = json.load(f)
    acct = ws.get('account_name') or ws.get('account_id', '')
    print(acct)
" 2>/dev/null
}

# Main logging function - called by CLI wrappers
# Usage: _nubifer_audit_log <provider> <outcome> <original_args...>
_nubifer_audit_log() {
    local provider="$1"
    local outcome="$2"
    shift 2

    # Fire and forget - run in background subshell
    (
        _nubifer_audit_init || return

        local user
        user=$(whoami)
        local ws_id="${NUBIFER_WORKSPACE_ID:-}"
        local ws_name="${NUBIFER_WORKSPACE_NAME:-}"
        local ro_val=0
        [ "$NUBIFER_WORKSPACE_READ_ONLY" = "true" ] && ro_val=1

        local cloud_account
        cloud_account=$(_nubifer_audit_get_account)

        local cred_name="${NUBIFER_AWS_CREDENTIAL:-${NUBIFER_WORKSPACE_NAME:-default}}"
        local cred_hint
        cred_hint=$(_nubifer_audit_get_cred_hint "$provider" "$cred_name")

        local session_id="${NUBIFER_AUDIT_SESSION:-$$}"

        # Build the full command string
        local full_command="$provider"
        local full_args="$*"

        # Escape single quotes for SQL
        full_args="${full_args//\'/\'\'}"
        ws_id="${ws_id//\'/\'\'}"
        ws_name="${ws_name//\'/\'\'}"
        cloud_account="${cloud_account//\'/\'\'}"
        cred_hint="${cred_hint//\'/\'\'}"
        cred_name="${cred_name//\'/\'\'}"

        sqlite3 "$NUBIFER_AUDIT_DB" "
            INSERT INTO command_log (user, workspace_id, workspace_name, provider, cloud_account, command, args, read_only, outcome, credential_hint, credential_name, session_id)
            VALUES ('${user}', '${ws_id}', '${ws_name}', '${provider}', '${cloud_account}', '${full_command}', '${full_args}', ${ro_val}, '${outcome}', '${cred_hint}', '${cred_name}', '${session_id}');
        " 2>/dev/null
    ) &
}
