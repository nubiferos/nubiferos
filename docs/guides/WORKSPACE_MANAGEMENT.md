# Workspace Management Guide

`nubifer-workspace` isolates your cloud accounts into named workspaces so you always know which account you are touching — and so a command meant for dev never lands in prod.

This guide covers creating, switching, and deleting workspaces, how isolation actually works (and where its limits are), shell prompt integration, and common workflows like multi-account AWS.

> **Companion guide:** [Credential Setup](CREDENTIAL_SETUP.md) covers storing the credentials that workspaces use.

## What a Workspace Is

A workspace is a named context for one cloud account:

- **Provider** — `aws`, `azure`, `gcp`, `oracle`, or `multi`
- **Account** — AWS account ID, Azure subscription ID, GCP project ID, or OCI tenancy
- **Region** — default region exported to CLIs
- **Mode** — read-write or read-only
- **Credentials** — stored per-workspace in `pass` (see [Credential Setup](CREDENTIAL_SETUP.md))

Each workspace gets a distinct color and icon in your terminal prompt (AWS orange, Azure blue, GCP multi-color, Oracle red, multi-cloud purple), so a glance tells you where you are.

## What a Workspace Is NOT

Be clear-eyed about the boundaries (see [Security Non-Goals](../SECURITY_NON_GOALS.md)):

- **Not an IAM boundary.** Read-only mode is enforced client-side by NubiferOS CLI wrappers, not by the cloud provider. Anything that calls the cloud API directly — SDK scripts, `curl`, Terraform, or the raw `/usr/bin/aws` binary — is not blocked. For real guarantees, use provider-side IAM policies. NubiferOS read-only mode is a guardrail against *accidents*, not a defense against a determined user or attacker.
- **Not a container.** Workspaces isolate environment variables and credential paths. Firejail sandboxing is applied to wrapped cloud CLIs where available, but your filesystem and network are shared across workspaces.
- **Not multi-user.** Workspace configs live in your home directory and are protected by file permissions (`0600`), not by separate user accounts.

## Command Reference

The real command surface (from `nubifer-workspace --help`):

```
nubifer-workspace {create,list,switch,current,delete,readonly,ro,rw,update,env}
```

| Command | Purpose |
|---------|---------|
| `create` | Create a workspace (auto-switches to it) |
| `list` | List workspaces, current one marked with `→` |
| `switch` | Switch by workspace ID or name |
| `current` | Show the active workspace |
| `delete` | Delete a workspace (not the active one) |
| `ro` | Lock: enable read-only mode |
| `rw` | Unlock: enable read-write mode (**requires sudo**) |
| `readonly` | Long-form read-only toggle (`--enable`/`--disable`) |
| `update` | Change name, account name, region, or credential ID |
| `env` | Print `export` lines for shell activation |

The alias `nw` is available in shells with NubiferOS integration loaded.

## Creating a Workspace

```bash
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 123456789012 \
  --account-name "prod-account" \
  --region us-east-1
```

Flags:

| Flag | Required | Meaning |
|------|----------|---------|
| `-n`, `--name` | yes | Display name |
| `-p`, `--provider` | yes | `aws`, `azure`, `gcp`, `oracle`, or `multi` |
| `-a`, `--account-id` | yes | Account / subscription / project / tenancy ID |
| `-r`, `--region` | yes | Default region (e.g. `us-east-1`, `eastus`, `us-central1`) |
| `--account-name` | no | Friendly display name (defaults to account ID) |
| `-c`, `--credential-id` | no | Credential name from `nubifer-creds` |
| `--read-only` | no | Start locked (recommended for production) |
| `-y`, `--yes` | no | Skip the confirmation prompt |

Behavior worth knowing:

- **One workspace per provider + account.** Creating a second workspace for the same AWS account is rejected; use `nubifer-workspace update <id> --region <region>` instead.
- You get a **review-and-confirm prompt** before creation (skip with `-y`).
- The new workspace **becomes the current workspace** immediately, and the command prints the `eval` line to activate it in your shell.

Examples for other providers:

```bash
# Azure (account-id = subscription ID)
nubifer-workspace create -n "Azure Dev" -p azure \
  -a 11111111-2222-3333-4444-555555555555 --account-name "dev-sub" -r eastus

# GCP (account-id = project ID)
nubifer-workspace create -n "GCP Staging" -p gcp \
  -a my-staging-project --account-name "staging" -r us-central1

# Production, locked from the start
nubifer-workspace create -n "AWS Prod" -p aws \
  -a 123456789012 -r us-east-1 --read-only
```

## Listing and Switching

```bash
nubifer-workspace list                  # all workspaces, current marked →
nubifer-workspace list --provider aws   # filter by provider

nubifer-workspace switch abc123def456       # by ID
nubifer-workspace switch "aws production"   # by name (case-insensitive)
```

### Activating in Your Current Shell

`switch` records the new current workspace and updates the GNOME context, but a child process cannot change your shell's environment. Two ways the environment gets applied:

1. **Automatic (recommended):** with shell integration loaded (`/etc/nubifer/shell-integration.sh`, sourced system-wide in `/etc/bash.bashrc`), a `PROMPT_COMMAND` hook detects the switch and loads the new environment at your **next prompt** — including switches made from the GNOME panel or another terminal.
2. **Explicit:**

```bash
eval $(nubifer-workspace env <workspace-id>)
# or, using the shell helper:
nw-activate <workspace-id>
```

Check where you are at any time:

```bash
nubifer-workspace current    # or: nw-context
```

## Read-Only Mode

Read-only mode blocks write operations issued through the NubiferOS CLI wrappers (`aws`, `az`, `gcloud`). It exists to make "I ran the terminate command in the wrong terminal" impossible in the common case.

### Locking and Unlocking

```bash
# Lock (no sudo needed — locking is always safe)
nubifer-workspace ro              # current workspace
nubifer-workspace ro <id>         # specific workspace

# Unlock (requires sudo — unlocking is a deliberate act)
sudo nubifer-workspace rw
sudo nubifer-workspace rw <id>

# Timed unlock: auto-reverts to read-only after N minutes
sudo nubifer-workspace rw -d 30

# Cancel a pending auto-revert timer
sudo nubifer-workspace rw -c
```

Why sudo for `rw`? It forces intentional action, blocks casual unlocking from a compromised shell session, and leaves a sudo audit trail. When invoked with sudo and no workspace ID, the tool resolves the invoking user's current workspace via `SUDO_USER`.

Timed unlock schedules the revert with a `systemd-run --user` timer. If scheduling fails (e.g. no user session), you get a warning telling you to lock manually — don't assume the timer fired if you log out mid-window.

### Honest limitation

The long-form `nubifer-workspace readonly <id> --disable` currently does **not** require sudo — a known gap in the enforcement story. Treat the sudo gate on `rw` as friction against accidents, not as an access control. And again: read-only mode only covers the wrapped CLIs. SDKs, Terraform, and direct API calls are unaffected.

### What Blocking Looks Like

```
 🔒 WRITE BLOCKED  Workspace is in read-only mode

  Command: aws ec2 terminate-instances --instance-ids i-123

  To enable writes (requires sudo):
    sudo nubifer-workspace rw <workspace-id>

  For timed write access (auto-reverts):
    sudo nubifer-workspace rw <workspace-id> -d 30  # 30 minutes
```

The AWS wrapper matches generic write verbs (`create`, `delete`, `update`, `put`, `terminate`, `run`, `invoke`, …) and S3 shorthand writes (`mb`, `rb`, `cp`, `mv`, `rm`, `sync`). Blocked and allowed commands are both recorded in the audit trail.

## How Isolation Works

When a workspace is active, three mechanisms combine:

### 1. Environment variables

`nubifer-workspace env` exports provider-specific context:

| Provider | Variables |
|----------|-----------|
| AWS | `AWS_DEFAULT_REGION`, `AWS_REGION`, `AWS_ACCOUNT_ID` |
| Azure | `AZURE_LOCATION`, `AZURE_SUBSCRIPTION_ID` |
| GCP | `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_REGION` |
| Oracle | `OCI_REGION`, `OCI_TENANCY` |
| All | `NUBIFER_WORKSPACE_ID`, `NUBIFER_WORKSPACE_NAME`, `NUBIFER_WORKSPACE_PROVIDER`, `NUBIFER_WORKSPACE_ACCOUNT`, `NUBIFER_WORKSPACE_ACCOUNT_ID`, `NUBIFER_WORKSPACE_READ_ONLY`, `NUBIFER_WORKSPACE` |
| All (Session Broker) | `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE`, `CLOUDSDK_CONFIG`, `AZURE_CONFIG_DIR` |

Note: secrets are **never** placed in environment variables — only context (region, account ID) and *paths* to workspace-scoped provider directories.

### 2. Workspace-scoped credentials

Credentials in `pass` are stored under `nubifer/<workspace-id>/...`, so switching workspaces switches which credentials the CLI wrappers can even see. The AWS wrapper builds a temporary AWS config file pointing `credential_process` at `nubifer-aws-credential-helper`, which decrypts credentials for the active workspace only. Details in [Credential Setup](CREDENTIAL_SETUP.md).

### 3. Workspace-scoped provider sessions (Session Broker)

Provider CLIs cache login sessions — AWS SSO tokens, `az` token caches, `gcloud` accounts and application-default credentials. By default those caches are global (`~/.aws`, `~/.azure`, `~/.config/gcloud`), so logging into one account would leak into every other context. NubiferOS relocates them per workspace by exporting four variables whenever a workspace is active:

| Variable | Points to |
|----------|-----------|
| `AWS_CONFIG_FILE` | `~/.config/nubifer/workspaces/<id>/providers/aws/config` |
| `AWS_SHARED_CREDENTIALS_FILE` | `~/.config/nubifer/workspaces/<id>/providers/aws/credentials` |
| `CLOUDSDK_CONFIG` | `~/.config/nubifer/workspaces/<id>/providers/gcloud` |
| `AZURE_CONFIG_DIR` | `~/.config/nubifer/workspaces/<id>/providers/azure` |

What this buys you:

- **Sessions cannot leak across workspaces.** `nubifer-creds login` in the prod workspace produces a session that the dev workspace cannot see — the caches are physically separate directory trees (`0700`, files `0600`).
- **Switching workspaces switches identities.** The same shell-integration hook that updates your prompt re-exports these variables at the next prompt; `eval $(nubifer-workspace env <id>)` and `nw-activate` set them explicitly.
- **No user configuration required.** The directories are created on workspace creation, and pre-existing workspaces get them lazily on first activation. The generated AWS config preserves the `credential_process` wiring, so static-key users are unaffected.
- **Your own settings are respected.** Deactivating only unsets these variables if they still point under `~/.config/nubifer/workspaces/` — a custom `AWS_CONFIG_FILE` you set yourself is never clobbered.

The scoped `aws/credentials` file stays an empty placeholder — static secrets live only in the pass vault, and SSO tokens live only in the provider CLI's scoped cache (e.g. `providers/aws/sso/cache/`). Guided login (`nubifer-creds login`) executes the provider CLIs inside this scope; see [Credential Setup](CREDENTIAL_SETUP.md#signing-in-with-sso-the-default).

### 4. CLI wrappers and sandboxing

Wrapped cloud CLIs enforce read-only mode, inject credentials via `credential_process` (no plaintext files, no env vars), log to the audit trail, and run under Firejail when it is installed.

### Desktop integration

Each workspace can be assigned to a GNOME virtual desktop; switching workspaces switches desktops, and the GNOME panel indicator shows the active provider, account, and lock state. This is cosmetic/ergonomic — it aids awareness, it does not isolate processes.

## Shell Prompt Integration

With a workspace active, your prompt shows the context with a high-visibility mode indicator:

```bash
# Read-only (green background = safe)
[🔒 Read-Only][☁️ prod-account] user@host:~$

# Read-write (red background = writes allowed)
[🔓 Read-Write][☁️ prod-account] user@host:~$
```

Convenience aliases loaded by the shell integration:

```bash
nw            # nubifer-workspace
nw-switch     # switch + activate in one step
nw-context    # show current workspace
nw-activate   # load a workspace's env into this shell
nc            # nubifer-creds
na            # nubifer-audit
```

If the prompt is stale: `source /etc/nubifer/shell-integration.sh` or `exec bash`.

## Common Workflows

### Multi-account AWS (dev / staging / prod)

```bash
# One workspace per account — prod starts locked
nubifer-workspace create -n "AWS Dev"     -p aws -a 111111111111 -r us-east-1 -y
nubifer-workspace create -n "AWS Staging" -p aws -a 222222222222 -r us-east-1 -y
nubifer-workspace create -n "AWS Prod"    -p aws -a 333333333333 -r us-east-1 --read-only -y

# Add credentials to each (switch first — creds are stored per workspace)
nw-switch "aws dev"      && nubifer-creds add -t aws -n default
nw-switch "aws staging"  && nubifer-creds add -t aws -n default
nw-switch "aws prod"     && nubifer-creds add -t aws -n default

# Daily work
nw-switch "aws dev"
aws s3 ls                          # uses dev credentials + region

# Careful prod change with an auto-closing window
nw-switch "aws prod"
sudo nubifer-workspace rw -d 15    # 15-minute write window
aws ec2 start-instances --instance-ids i-abc123
nubifer-workspace ro               # or just let the timer revert it
```

### Safe production browsing

Keep prod permanently read-only. Check dashboards, list resources, describe instances — all reads work; any wrapped write is blocked until you deliberately `sudo nubifer-workspace rw`.

### Multi-cloud project

Create one workspace per provider (`aws`, `azure`, `gcp`) rather than a single `multi` workspace when you need distinct credentials and prompt colors per provider. Use `multi` only for orchestration contexts that genuinely span clouds.

## Updating and Deleting

```bash
# Update mutable fields (name, account-name, region, credential-id)
nubifer-workspace update <id> --region us-west-2

# Delete — you cannot delete the active workspace; switch away first
nubifer-workspace switch <other-id>
nubifer-workspace delete <id>
```

Deleting a workspace removes its config file **and** its scoped provider directory tree (`~/.config/nubifer/workspaces/<id>/`) — every file in it, including cached SSO/session tokens, is zero-overwritten (best-effort shred) before the tree is removed, so a deleted workspace leaves no live sessions behind.

It does **not** delete credentials stored under `nubifer/<workspace-id>/` in `pass` — remove those separately with `nubifer-creds remove` if the account is being retired. If you want provider-side certainty, `nubifer-creds logout` before deleting also revokes the sessions with the providers.

## Audit Log

Every workspace operation is appended to `~/.config/nubifer/workspace-audit.log`:

```
2026-01-12T10:30:00 | user | CREATE | abc123 | name=AWS Production, provider=aws
2026-01-12T10:31:00 | user | SWITCH | abc123 | name=AWS Production
2026-01-12T10:35:00 | user | SET_READ_ONLY | abc123 | mode=enabled, duration=0
```

Review it periodically for anything you don't recognize. Note that it is an append-only *file* with `0600` permissions, not a tamper-proof log — anyone with your user account can edit it.

## Files

```
~/.config/nubifer/
├── workspaces/<id>.json     # Workspace configs (0600)
├── workspaces/<id>/         # Workspace data dir (0700)
│   └── providers/           # Session Broker: scoped provider configs/caches
│       ├── aws/config       # Generated AWS config (0600, credential_process / SSO)
│       ├── aws/credentials  # Empty placeholder — secrets never land here
│       ├── aws/sso/cache/   # AWS SSO token cache (this workspace only)
│       ├── gcloud/          # CLOUDSDK_CONFIG root
│       └── azure/           # AZURE_CONFIG_DIR root
├── current-workspace        # Active workspace ID
└── workspace-audit.log      # Audit log (0600)

/etc/nubifer/shell-integration.sh   # Prompt + aliases (sourced system-wide)
/usr/local/bin/nubifer-workspace    # The command
```

## Troubleshooting

**Prompt not updating** — `source /etc/nubifer/shell-integration.sh` or restart the shell. The auto-sync hook only runs at prompt display, so long-running commands won't see a mid-flight switch.

**Environment variables not set** — `switch` alone doesn't modify an existing shell. Run `eval $(nubifer-workspace env <id>)` or `nw-activate <id>`, or just press Enter once to let the prompt hook catch up.

**"Workspace already exists for this account"** — one workspace per provider+account is enforced. Update the existing one instead.

**Cannot delete workspace** — you're trying to delete the active one. Switch away first.

**Read-only mode "not working"** — enforcement lives in the CLI wrappers. If you invoke `/usr/bin/aws` directly, or the wrappers aren't installed on your PATH ahead of the real binaries, nothing is blocked. Check with `type aws` — it should resolve to the NubiferOS wrapper.
