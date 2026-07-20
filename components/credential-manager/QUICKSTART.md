# Credential Manager Quick Start

`nubifer-creds` ships preinstalled on NubiferOS — nothing to install. This is the five-minute version; the full walkthrough (wizard details, rotation, backup, threat model) is in the [Credential Setup Guide](../../docs/guides/CREDENTIAL_SETUP.md).

## 1. First-Time Setup

Run the setup wizard (or click "Set Up Credential Manager" in the Welcome app):

```bash
nubifer-setup-wizard          # generates GPG key if needed, runs `pass init`
nubifer-setup-wizard status   # check GPG / pass state
```

Prefer a passphrase-protected key? Set it up manually instead — see the [GPG Setup Guide](../../docs/guides/GPG_SETUP_GUIDE.md):

```bash
gpg --full-generate-key        # RSA 4096, strong passphrase
pass init your-email@example.com
```

## 2. Pick Your Workspace First

Credentials are stored **per workspace**. Create/switch before adding, or they land in a workspace literally named `default`:

```bash
nubifer-workspace list
nubifer-workspace switch <workspace-id>
```

The `add` command shows which workspace it's targeting before writing — read it. Use `-w <workspace-id>` to target explicitly, `-y` to skip the confirmation.

## 3. Add Credentials

```bash
# AWS (prompts for Access Key ID + Secret Access Key, hidden input)
nubifer-creds add -t aws -n default

# Azure service principal (prompts for Tenant ID, Client ID, Client Secret)
nubifer-creds add -t azure -n dev-sp

# GCP service account (prompts for Project ID + key file path)
# WARNING: the original JSON key file is deleted after import
nubifer-creds add -t gcp -n staging

# API token (GitHub etc.)
nubifer-creds add -t api -n github
```

AWS naming tip: the `aws` wrapper looks for a credential named after your **workspace name**, then falls back to `default`. Naming it `default` always works.

Adding AWS credentials enables **STS token mode** by default: the AWS CLI gets short-lived session tokens while your base keys stay encrypted in pass. Opt out with `--no-sts`, tune with `--sts-duration <seconds>`.

## 4. Use Them

```bash
aws sts get-caller-identity    # the wrapper injects credentials automatically
```

No `aws configure`, no `~/.aws/credentials` — the wrapper uses `credential_process` with `nubifer-aws-credential-helper`. If `aws` says "unable to locate credentials," check you're in the right workspace and the credential name is `default` or matches the workspace name.

## 5. List, Retrieve, Remove

```bash
nubifer-creds list                           # everything in the active workspace
nubifer-creds list -t aws                    # filter by provider

nubifer-creds get -t aws -n default          # masked display
nubifer-creds get -t azure -n dev-sp --json  # full values — treat output as a secret

nubifer-creds remove cloud/aws/default       # path, not flags
```

Or inspect the store directly with pass:

```bash
pass ls nubifer
pass show nubifer/<workspace-id>/cloud/aws/default/access-key-id
```

Every add/access/remove is logged to `~/.config/nubifer/audit.log` (paths and actions only — never secret values).

## 6. Manage STS Tokens (AWS)

```bash
nubifer-creds token status  -t aws -n default          # mode, duration, cached-token expiry
nubifer-creds token refresh -t aws -n default          # force-mint a new token
nubifer-creds token clear   -t aws -n default          # drop the cached token
nubifer-creds token disable -t aws -n default          # revert to static credentials
nubifer-creds token enable  -t aws -n default --duration 3600   # 900–43200 seconds
```

## 7. Prefer SSO? (Recommended Where Available)

Static keys work, but if your org uses AWS IAM Identity Center, Entra ID, or Google sign-in, use SSO instead — short-lived tokens, scoped to the workspace, nothing long-lived to rotate:

```bash
# One-time NON-SECRET setup (stored in the workspace config, never in pass)
nubifer-creds login setup -t aws --sso-start-url https://my-org.awsapps.com/start \
    --sso-region us-east-1 --sso-account-id 123456789012 --sso-role-name DevAccess

nubifer-creds login -t aws     # runs `aws sso login` inside the workspace scope
nubifer-creds status           # per-provider: mode (sso/static/none), identity, expiry
nubifer-creds logout           # revoke sessions + clear session metadata
```

Azure and GCP work the same way: `login setup -t azure --tenant <id> --subscription <id>` then `login -t azure` (device code); `login setup -t gcp --project <id> --impersonate-service-account <sa>` then `login -t gcp`. Optional least-privilege binding for AWS: `login setup -t aws --role-arn arn:aws:iam::...:role/Deployer`.

When both SSO and static keys exist, **SSO wins** — static credentials stay reachable as the `nubifer-static` AWS profile. Logins and expiry are recorded in the audit log (never token material).

## Backup (Do This Now)

Lose your GPG key and every stored credential is permanently unrecoverable:

```bash
nubifer-setup-wizard backup    # exports private key to ~/gpg-private-key-backup-YYYYMMDD.asc
```

Move the export to an encrypted USB drive or offline storage — never commit it or sync it to plain cloud storage. Optionally version the (already encrypted) store with `pass git init`. Full backup/restore procedure: [Credential Setup Guide](../../docs/guides/CREDENTIAL_SETUP.md#backup-and-recovery).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "pass (password-store) not initialized" | Run `nubifer-setup-wizard`, or `pass init <gpg-key-id>` |
| Credentials added but `aws` can't find them | Wrong workspace — `nubifer-creds list` shows where you are. Also check the credential name is `default` or matches the workspace name |
| "STS token mode: not available (missing dependencies)" | `pip install boto3 cryptography` — static credentials keep working meanwhile |
| Helper hangs (pinentry with no TTY) | Run a wrapped `aws` command from a terminal once, or `export GPG_TTY=$(tty)` |
| Frequent GPG passphrase prompts | Add `default-cache-ttl 3600` / `max-cache-ttl 7200` to `~/.gnupg/gpg-agent.conf`, then `gpgconf --kill gpg-agent` |

## Security Tips

1. Back up your GPG key **before** you need it
2. Prefer prompted input over `--access-key-id`-style flags (flags end up in shell history)
3. Treat `get --json` output as a secret — don't pipe it into files or logs
4. Shorter STS durations shrink the window a stolen token is useful; 1 hour is a sane default
5. Rotation isn't automatic yet — rotate manually and revoke the old key server-side ([procedure](../../docs/guides/CREDENTIAL_SETUP.md#rotating-credentials))
