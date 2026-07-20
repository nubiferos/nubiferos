# NubiferOS Credential Manager

Secure, workspace-scoped credential management for cloud accounts using `pass` (password-store) with GPG encryption. No custom cryptography, no plaintext secrets on disk.

> **User-facing documentation:** [Credential Setup Guide](../../docs/guides/CREDENTIAL_SETUP.md) is the canonical how-to (first-boot wizard, adding credentials, rotation, backup). [Credential Security](../../docs/CREDENTIAL_SECURITY.md) covers the threat model. This README documents the component itself: what ships, how it's laid out, and how it integrates.

## What Actually Ships

The build (`build/build-iso.sh`, `build/build-debs.sh`) installs exactly three pieces:

| Source | Installed to | Purpose |
|--------|--------------|---------|
| `nubifer-creds` | `/usr/local/bin/nubifer-creds` | CLI: add/list/get/remove credentials, manage STS tokens |
| `nubifer-aws-credential-helper` | `/usr/local/bin/nubifer-aws-credential-helper` | `credential_process` helper for the AWS CLI |
| `src/token_cache.py`, `src/token_generators/*.py` | `/usr/local/lib/nubifer/credential-manager/src/` | STS token caching and generation modules |

`nubifer-creds` is a single self-contained Python script — a thin, auditable wrapper around `pass`. There is no daemon, no D-Bus service, and no metadata database in the shipped design (see [Legacy / unshipped code](#legacy--unshipped-code)).

## Architecture

- **Storage backend:** `pass` (password-store), GPG-encrypted at rest
- **Workspace scoping:** every credential lives under the active workspace's prefix; switching workspaces switches which credentials CLIs see
- **AWS integration:** the `aws` CLI wrapper (from `components/workspace-manager/`) injects credentials via `credential_process` — secrets never sit in environment variables or `~/.aws/credentials`
- **STS token mode (default for AWS):** the CLI receives short-lived session tokens; long-lived keys are only decrypted to mint a new token
- **Audit log:** every add/access/remove is appended to `~/.config/nubifer/audit.log` (timestamp, user, workspace, action, path — never secret values)

## CLI Interface

Command surface: `add`, `list`, `get`, `remove`, `token` (static keys) plus `login`, `logout`, `status` (SSO sessions — see [SSO Sessions](#sso-sessions-modern-auth)).

```bash
# Add credentials (prompts for secrets with hidden input)
nubifer-creds add -t aws   -n default        # --access-key-id, --secret-access-key, --no-sts, --sts-duration
nubifer-creds add -t azure -n dev-sp         # --tenant-id, --client-id, --client-secret
nubifer-creds add -t gcp   -n staging        # --project-id, --key-file (original file is DELETED after import)
nubifer-creds add -t api   -n github         # --token, --scopes

# Common add flags: -w <workspace-id> (target a non-active workspace), -y (skip confirmation)

# List / retrieve / remove
nubifer-creds list                           # all credentials in the active workspace
nubifer-creds list -t aws                    # filter by cloud provider type
nubifer-creds get -t aws -n default          # masked display; --json prints full values
nubifer-creds remove cloud/aws/default       # positional path, not flags

# STS token management (AWS only)
nubifer-creds token status  -t aws -n default
nubifer-creds token enable  -t aws -n default --duration 3600   # 900–43200 seconds
nubifer-creds token disable -t aws -n default
nubifer-creds token clear   -t aws -n default
nubifer-creds token refresh -t aws -n default
```

Honest quirks of the current CLI:

- `list -t <type>` filters under `cloud/<type>`, so it works for `aws`/`azure`/`gcp` but not for `api` tokens (use plain `list` or `pass ls`)

## SSO Sessions (Modern Auth)

Static keys are the legacy fallback; the recommended flow is provider-native SSO. The provider CLIs (`aws sso login`, `az login`, `gcloud auth login`) own their token lifecycles — NubiferOS scopes each provider's config and token cache to the active workspace (Session Broker, workspace-manager component) and `nubifer-creds` orchestrates the login.

```bash
# One-time, NON-SECRET configuration — stored in the workspace config, never in pass
nubifer-creds login setup -t aws --sso-start-url https://my-org.awsapps.com/start \
    --sso-region us-east-1 --sso-account-id 123456789012 --sso-role-name DevAccess
nubifer-creds login setup -t azure --tenant <tenant-id> --subscription <subscription-id>
nubifer-creds login setup -t gcp --project my-project \
    --impersonate-service-account deploy@my-project.iam.gserviceaccount.com

# Optional AWS role binding: all default-profile calls assume this role
nubifer-creds login setup -t aws --role-arn arn:aws:iam::123456789012:role/Deployer

# Log in / out, executed with the workspace-scoped provider dirs
nubifer-creds login -t aws        # aws sso login (uses the stored sso-session)
nubifer-creds login -t azure      # az login --use-device-code [--tenant], then az account set
nubifer-creds login -t gcp        # gcloud auth login + impersonation/project bindings
nubifer-creds logout              # all recorded sessions; -t <provider> for one

# Per-provider session table: auth mode (sso/static/none), identity, expiry
nubifer-creds status              # --json for scripts; -w <workspace-id> to target
```

What lives where:

- **Workspace config** (`~/.config/nubifer/workspaces/<id>.json`): SSO start URL/region/account/role, Azure tenant/subscription, GCP project/impersonation, and non-secret session metadata (identity, expiry) recorded after login. Never token material.
- **Workspace-scoped provider dirs** (`.../workspaces/<id>/providers/`): the tokens themselves, cached by the provider CLIs. Shredded when the workspace is deleted.
- **pass vault**: static keys only. SSO tokens are never written to pass.

**Resolution order (SSO > static):** with SSO configured, the generated scoped AWS config makes `[default]` resolve via the SSO session (through `role_arn` if bound); the static `credential_process` path remains available as the `nubifer-static` profile (`AWS_PROFILE=nubifer-static`). Without SSO configuration, `[default]` keeps the original `credential_process` wiring — the static flow is byte-for-byte unchanged. Generated configs carry a `# Generated by NubiferOS` first-line marker; user-edited files are never overwritten.

Honest limits: expiry is only cheaply available for AWS (read from the scoped SSO token cache) — `status` shows `provider-managed` for az/gcloud sessions. "Non-interactive" means the stored configuration removes per-provider incantations, not that the browser/device-code step disappears. `login`, `logout`, failures, and detected expiry are audit-logged (`LOGIN`, `LOGIN_FAILED`, `LOGOUT`, `SESSION_EXPIRED`) with the same non-secret discipline as the rest of the log.

## Storage Layout

Credentials are stored in pass under a **workspace-scoped** prefix. The active workspace comes from `NUBIFER_WORKSPACE_ID` (set by `nubifer-workspace` / shell integration); with no active workspace, the literal workspace `default` is used.

```
~/.password-store/
└── nubifer/
    └── <workspace-id>/
        ├── cloud/
        │   ├── aws/
        │   │   └── <profile>/
        │   │       ├── access-key-id.gpg
        │   │       ├── secret-access-key.gpg
        │   │       └── session-token.gpg      # optional, manually stored
        │   ├── azure/
        │   │   └── <name>/
        │   │       ├── tenant-id.gpg
        │   │       ├── client-id.gpg
        │   │       └── client-secret.gpg
        │   └── gcp/
        │       └── <name>/
        │           ├── project-id.gpg
        │           └── service-account-key.gpg  # full JSON, multiline
        └── api/
            └── <service>/
                ├── token.gpg
                └── scopes.gpg
```

Region is **not** stored on the credential — it belongs to the workspace.

## AWS CLI Integration (`credential_process`)

You never run `aws configure` on NubiferOS. The `aws` wrapper (workspace-manager component) writes a temporary AWS config pointing at the helper:

```ini
[default]
credential_process = /usr/local/bin/nubifer-aws-credential-helper <cred-name>
region = <workspace region>
```

The helper:

1. Reads the workspace from `NUBIFER_WORKSPACE` (exported by the wrapper from `NUBIFER_WORKSPACE_ID`) and the credential name from its argument (or `NUBIFER_AWS_CREDENTIAL`)
2. **Token mode enabled:** returns a cached STS token, minting and caching a fresh one when expired or within 5 minutes of expiry
3. **Token mode disabled or STS fails:** falls back to static credentials from pass (a warning goes to stderr, your command still runs)
4. Emits standard `credential_process` JSON (`Version: 1`)

The wrapper also pre-warms the GPG agent in your terminal so the helper (which has no TTY) can decrypt without hanging on a pinentry prompt. Calling `/usr/bin/aws` directly bypasses injection entirely — you get "unable to locate credentials," which is the safe failure mode.

## STS Token Mode

Enabled by default when adding AWS credentials (`--no-sts` to opt out). Implementation:

- `src/token_generators/aws.py` — calls `sts:GetSessionToken` with the base keys from pass; durations clamped to AWS limits (900–43200 seconds, default 3600)
- `src/token_cache.py` — caches tokens as Fernet-encrypted files in `~/.config/nubiferos/token_cache/` (key derived via PBKDF2 from `/etc/machine-id`); expiration metadata in SQLite at `~/.config/nubiferos/token_cache.db`

The cache encryption is deliberately modest: it protects short-lived tokens from casual file disclosure, not from an attacker running as your user (who could read the machine-id and derive the key). The real protection is that the tokens expire; the long-lived keys stay behind GPG.

Requires `boto3` and `cryptography` (preinstalled on NubiferOS). If missing, `add` still succeeds and falls back to static credentials — the output tells you which mode you got.

## Security

**Encrypted:** every credential value, at rest, with your GPG key (via pass).

**Not encrypted:** the pass directory structure (workspace IDs, providers, credential names), the audit log, token cache metadata. An attacker with file access learns *which* accounts you have, not the keys to them.

**Out of scope:** compromise of your running session. Malware running as your user while the GPG agent is unlocked can read credentials the same way the CLI wrappers do. Full-disk encryption plus a locked screen is the boundary — see [Credential Security](../../docs/CREDENTIAL_SECURITY.md).

## Installation

On NubiferOS this component is installed by the image build / `nubifer-creds` deb — there is nothing to install by hand. First-boot setup (GPG key + `pass init`) is handled by `nubifer-setup-wizard`; see the [Credential Setup Guide](../../docs/guides/CREDENTIAL_SETUP.md).

Prerequisites at runtime: `pass`, `gnupg`, an initialized password store. `nubifer-creds` exits with instructions if the store isn't initialized.

> `install.sh` in this directory installs the **legacy** stack below, and would shadow the shipped `nubifer-creds` with the old click-based CLI. Don't use it.

## Legacy / Unshipped Code

This directory also contains an earlier daemon-based design that is **not shipped** and does not match the current CLI:

- `src/cli.py`, `src/credential_service.py`, `src/pass_backend.py` — click-based CLI with `init`/`status`/`show`/`test`/`delete` subcommands, `--provider`/`--account-id` flags, pass paths under `nubiferos/credentials/`, and a SQLite metadata DB
- `src/dbus_interface.py`, `systemd/` — `org.nubiferos.CredentialManager` D-Bus service and unit files
- `install.sh`, `test_manual.sh` — install/test scripts for that stack
- The `dbus-python`, `click`, and `pydantic` entries in `requirements.txt` belong to this stack; `keyring` was for an earlier token-cache backend

Only `src/token_cache.py` and `src/token_generators/` from `src/` are part of the shipped system. The rest is kept for reference until a decision is made on a future D-Bus interface; treat it as historical.

## Tests

```bash
pytest components/credential-manager/tests/    # token cache + AWS token generator
python3 -m unittest tests.test_modern_auth     # SSO login/status (offline, mocked)
python3 -m py_compile nubifer-creds nubifer-aws-credential-helper
```

## Future Enhancements

- [ ] Automatic credential rotation (manual procedure documented in the setup guide)
- [ ] Azure/GCP credential injection as integrated as AWS's `credential_process` flow
- [ ] `db`/`ssh` credential types (not yet implemented; rejected by the CLI)
- [x] OIDC/SSO authentication (`login`/`logout`/`status` — see [SSO Sessions](#sso-sessions-modern-auth))
- [ ] Hardware key support (YubiKey)

## License

Part of NubiferOS - GPL-3.0
