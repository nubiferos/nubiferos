# Credential Setup Guide

How to set up credential management on NubiferOS: the first-boot wizard, GPG key and `pass` initialization, adding AWS/Azure/GCP credentials with `nubifer-creds`, how the AWS CLI picks credentials up via `credential_process`, and how to rotate and back up.

> **Companion guide:** [Workspace Management](WORKSPACE_MANAGEMENT.md). Credentials are stored **per workspace** — create or switch to the right workspace before adding them.

## Architecture in One Paragraph

`nubifer-creds` is a thin, auditable wrapper around `pass` (password-store). Secrets are encrypted at rest with your **GPG key** — battle-tested tooling, no custom cryptography. Credentials are namespaced by workspace (`nubifer/<workspace-id>/cloud/<provider>/<name>/...`), so switching workspaces switches which credentials your CLIs see. For AWS, static keys are protected further by **STS token mode** (on by default): the CLI receives short-lived session tokens while your long-lived keys stay encrypted in `pass`. See [Credential Security](../CREDENTIAL_SECURITY.md) for the threat model.

## First-Boot Setup

### The graphical path

On first login after installation, the **NubiferOS Welcome** app (`nubifer-welcome`) runs. Its credential page has a **"Set Up Credential Manager"** button that opens a terminal running `nubifer-setup-wizard setup`. When it completes, setup status refreshes and a flag is written to `~/.config/nubiferos/setup-complete`.

### The terminal path

You can run the same wizard any time:

```bash
nubifer-setup-wizard          # or: nubifer-setup-wizard setup
nubifer-setup-wizard status   # check GPG / pass / git state
nubifer-setup-wizard backup   # export your private GPG key
```

The wizard:

1. Checks that `gnupg` and `pass` are installed
2. Generates a GPG key if you don't have one (RSA 4096-bit, no expiration)
3. Runs `pass init <your-key-id>`
4. Optionally initializes a git repo inside the password store for versioned backup

### Honest note on the wizard's GPG key

The wizard generates its key **without a passphrase** for convenience — anyone with access to your logged-in session can decrypt your credentials. That trade-off is acceptable on a full-disk-encrypted, single-user machine (which NubiferOS is), but if you want a passphrase-protected key — recommended for higher-value accounts — set it up manually instead. The full manual procedure, key parameters, agent caching, and backup/restore steps are in the [GPG Setup Guide](GPG_SETUP_GUIDE.md); the short version:

```bash
gpg --full-generate-key        # RSA 4096, strong passphrase
pass init your-email@example.com
```

## Before Adding Credentials: Pick Your Workspace

`nubifer-creds` stores credentials under the **active** workspace (`NUBIFER_WORKSPACE_ID`). With no active workspace, they land in a workspace literally named `default`. The `add` command shows a confirmation of the target workspace before writing — read it. To target explicitly:

```bash
nubifer-creds add -t aws -n prod -w <workspace-id>   # explicit workspace
nubifer-creds add -t aws -n prod -y                  # skip confirmation
```

## Adding Credentials

Command surface (from `nubifer-creds --help`): `add`, `list`, `get`, `remove`, `token`.

### AWS

```bash
nubifer-creds add -t aws -n default
# Prompts for: AWS Access Key ID, AWS Secret Access Key (hidden input)
```

Flags: `--access-key-id`, `--secret-access-key` (avoid these on shared machines — they end up in shell history), `--no-sts`, `--sts-duration <seconds>` (default 3600).

By default this also **enables STS token mode**: the AWS CLI gets temporary session tokens generated from your base keys, and the base keys are only decrypted to mint a new token. If the Python dependencies for token mode (`keyring`, `cryptography`, `boto3`) are missing, the add still succeeds and falls back to static credentials — the output tells you which mode you got.

Naming tip: the AWS wrapper looks for a credential named after your **workspace name**, then falls back to `default`. Naming your credential `default` always works; use distinct names only when a workspace needs multiple credential sets (select with `NUBIFER_AWS_CREDENTIAL=<name>`).

Region is **not** part of the credential — it comes from the workspace.

### Azure (service principal)

```bash
nubifer-creds add -t azure -n dev-sp
# Prompts for: Tenant ID, Client ID, Client Secret
```

Flags: `--tenant-id`, `--client-id`, `--client-secret`.

### GCP (service account)

```bash
nubifer-creds add -t gcp -n staging
# Prompts for: GCP Project ID, path to service account JSON key file
```

Flags: `--project-id`, `--key-file`.

**Warning:** the original JSON key file is **deleted** after import — the encrypted copy in `pass` becomes the only local copy. If you need the plaintext file elsewhere, copy it first (and think hard about why).

### API tokens (GitHub, etc.)

```bash
nubifer-creds add -t api -n github
# Prompts for the token (hidden input); optional --scopes
```

## Listing, Retrieving, Removing

```bash
nubifer-creds list                 # all credentials in the active workspace
nubifer-creds list -t aws          # filter by type

nubifer-creds get -t aws -n default          # masked display
nubifer-creds get -t azure -n dev-sp --json  # full values as JSON — treat output as a secret

nubifer-creds remove cloud/aws/default       # path, not flags
```

Every add, access, and removal is appended to `~/.config/nubifer/audit.log` (timestamp, user, workspace, action, path — never the secret values).

You can also inspect the store directly with standard `pass` commands:

```bash
pass ls nubifer
pass show nubifer/<workspace-id>/cloud/aws/default/access-key-id
```

## How the AWS CLI Gets Credentials (`credential_process`)

You do not run `aws configure` on NubiferOS, and there is no `~/.aws/credentials` file with plaintext keys. Instead, the NubiferOS `aws` wrapper:

1. Verifies a workspace is active and read-only mode allows the command
2. Writes a **temporary** AWS config file (deleted on exit) containing:
   ```ini
   [default]
   credential_process = /usr/local/bin/nubifer-aws-credential-helper <cred-name>
   region = <workspace region>
   ```
3. Pre-warms the GPG agent in your terminal so the helper (which has no TTY) can decrypt without hanging on a pinentry prompt
4. Executes the real AWS CLI — under Firejail if installed

The helper returns cached STS tokens when token mode is enabled (auto-refreshing near expiry), or static credentials otherwise. If STS generation fails, it falls back to static credentials and logs a warning rather than breaking your command.

Practical consequences:

- Secrets never sit in environment variables or on-disk plaintext
- `aws` only works with credentials after the GPG agent can decrypt (first use may prompt, depending on your key setup)
- Bypassing the wrapper (`/usr/bin/aws` directly) bypasses credential injection too — you'll get "unable to locate credentials," which is the safe failure mode

Azure and GCP wrappers use the workspace environment (subscription/project variables); their credential injection is less integrated than AWS's `credential_process` flow today.

## STS Token Management

```bash
nubifer-creds token status  -t aws -n default          # mode, duration, cached-token expiry
nubifer-creds token enable  -t aws -n default --duration 3600   # 900–43200 seconds
nubifer-creds token disable -t aws -n default          # revert to static credentials
nubifer-creds token clear   -t aws -n default          # drop cached token; new one on next use
nubifer-creds token refresh -t aws -n default          # force-mint a new token now
```

All token subcommands accept `-w <workspace-id>` to target a non-active workspace. Only AWS is supported currently.

Shorter durations mean a stolen token is useful for less time, at the cost of more frequent GPG decryptions of the base key. 1 hour (the default) is a reasonable balance for interactive work.

## Rotating Credentials

Automatic rotation is **not implemented** (it's on the roadmap). The manual procedure:

1. Create the new access key / client secret / service account key in the cloud console
2. Replace the stored values:
   ```bash
   nubifer-creds remove cloud/aws/default
   nubifer-creds add -t aws -n default        # enter the new keys
   ```
3. If token mode is on, clear the cache so nothing stale is served:
   ```bash
   nubifer-creds token clear -t aws -n default
   ```
4. Verify (`aws sts get-caller-identity`), then **revoke the old key in the cloud console**. Rotation isn't done until the old credential is dead server-side.

Do this per workspace — each workspace's credentials are independent copies.

## Backup and Recovery

Two things to back up; losing the first makes the second unreadable:

1. **Your GPG private key** — without it, every stored credential is permanently unrecoverable:
   ```bash
   nubifer-setup-wizard backup
   # writes ~/gpg-private-key-backup-YYYYMMDD.asc (chmod 600)
   ```
   Move it to an encrypted USB drive or offline storage. Never commit it, never sync it to plain cloud storage.
2. **The password store** — optionally versioned with git:
   ```bash
   pass git init
   pass git remote add origin <private-repo-url>
   pass git push -u origin main
   ```
   The store contents are GPG-encrypted, so a private git remote is acceptable — but note the *structure* (workspace IDs, provider names, profile names) is visible as directory names to anyone who can read the repo.

Recovery on a fresh machine: import the GPG key (`gpg --import backup.asc`), clone or restore `~/.password-store`, and `nubifer-creds list` should work.

## What's Protected and What Isn't

**Encrypted:** every credential value, at rest, with your GPG key.

**Not encrypted:** the pass directory structure (workspace IDs, providers, credential names), the audit log, and workspace metadata. An attacker with file access learns *which* accounts you have, not the keys to them.

**Out of scope:** a compromise of your running session. If malware runs as your user while the GPG agent is unlocked, it can read credentials the same way the CLI wrappers do. Full-disk encryption plus a locked screen is the boundary; see [Security Non-Goals](../SECURITY_NON_GOALS.md).

## Troubleshooting

**"pass (password-store) not initialized"** — run `nubifer-setup-wizard`, or manually `pass init <gpg-key-id>` (create a key first with `gpg --full-generate-key` if needed).

**Credentials added but `aws` can't find them** — check the workspace: `nubifer-creds list` shows which workspace you're looking at. Credentials added with no active workspace went to `default`, not your current workspace. Also confirm the credential name is `default` or matches the workspace name.

**Frequent GPG passphrase prompts** — extend agent caching:
```bash
echo "default-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 7200" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

**"STS token mode: not available (missing dependencies)"** — `pip install keyring cryptography boto3`. Static credentials keep working in the meantime.

**Credential helper hangs** — usually a pinentry with no TTY. Run any wrapped `aws` command from a terminal once (the wrapper pre-warms the agent), or set `export GPG_TTY=$(tty)` in your shell.
