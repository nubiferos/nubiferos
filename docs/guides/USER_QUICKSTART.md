# NubiferOS User Quick Start

From first login to running cloud commands with encrypted credentials and workspace isolation — about ten minutes.

> Looking to *build* NubiferOS instead? See the [build quick start](../QUICKSTART.md) and the [Quick Build Guide](../QUICK_BUILD_GUIDE.md). Installing the OS? See the [Installer Quickstart](INSTALLER_QUICKSTART.md).

## 1. First Login

After installation, the **NubiferOS Welcome** app opens. It walks you through what's on the system and offers to set up the credential manager. You can do everything from there, or follow the terminal steps below — they're the same operations.

## 2. Initialize Credential Storage (once)

```bash
nubifer-setup-wizard
```

This checks for a GPG key (generates one if needed), initializes `pass` (the encrypted credential store), and optionally sets up git-based backup. Verify with:

```bash
nubifer-setup-wizard status
```

Note: the wizard's auto-generated GPG key has no passphrase — fine for a full-disk-encrypted single-user machine, but if you want a passphrase-protected key, follow the manual path in the [Credential Setup guide](CREDENTIAL_SETUP.md) first.

**Do this before anything else matters:** back up your GPG key. If you lose it, every stored credential is unrecoverable.

```bash
nubifer-setup-wizard backup   # move the .asc file to an encrypted USB drive
```

## 3. Create Your First Workspace

A workspace pins your terminal to one cloud account, with a color-coded prompt so you always know where you are.

```bash
nubifer-workspace create \
  --name "AWS Dev" \
  --provider aws \
  --account-id 111111111111 \
  --region us-east-1
```

Confirm the summary, and the workspace becomes active. Activate it in your current shell:

```bash
eval $(nubifer-workspace env <workspace-id>)   # ID is printed by create
```

(New terminals pick up the active workspace automatically via shell integration.)

## 4. Add Credentials to the Workspace

```bash
nubifer-creds add -t aws -n default
```

You'll confirm the target workspace, then enter your access key ID and secret (hidden input). Both are encrypted with your GPG key; by default the AWS CLI will use short-lived STS tokens instead of your long-lived keys.

## 5. Run a Cloud Command

```bash
aws sts get-caller-identity
aws s3 ls
```

No `aws configure`, no plaintext `~/.aws/credentials` — the NubiferOS wrapper injects credentials from encrypted storage via `credential_process`, scoped to the active workspace.

## 6. Add a Production Workspace — Locked

```bash
nubifer-workspace create -n "AWS Prod" -p aws -a 333333333333 -r us-east-1 --read-only
eval $(nubifer-workspace env <prod-workspace-id>)
nubifer-creds add -t aws -n default
```

Your prompt now shows a green `🔒 Read-Only` badge. Reads work; wrapped write commands are blocked. When you genuinely need to change prod:

```bash
sudo nubifer-workspace rw -d 15   # 15-minute write window, auto-reverts
```

Be honest with yourself about what this is: a client-side guardrail against wrong-terminal accidents, not an IAM policy. Direct SDK/API calls are not blocked.

## 7. Daily Driving

```bash
nw list                    # list workspaces (nw = nubifer-workspace)
nw-switch "aws dev"        # switch + activate in one step
nw-context                 # where am I?
nc list                    # credentials in this workspace (nc = nubifer-creds)
nubifer-workspace ro       # lock the current workspace when done
```

Watch the prompt: **green = read-only (safe), red = read-write (careful)**, and the icon/color tells you the provider and account.

## Where to Go Next

| Topic | Guide |
|-------|-------|
| Workspaces in depth: isolation, read-only mode, multi-account workflows | [Workspace Management](WORKSPACE_MANAGEMENT.md) |
| Credentials in depth: Azure/GCP, STS tokens, rotation, backup | [Credential Setup](CREDENTIAL_SETUP.md) |
| GPG keys: manual setup, agent caching, backup/restore | [GPG Setup Guide](GPG_SETUP_GUIDE.md) |
| What NubiferOS deliberately does not protect against | [Security Non-Goals](../SECURITY_NON_GOALS.md) |
| Credential threat model | [Credential Security](../CREDENTIAL_SECURITY.md) |
| Recovery key from installation | [Recovery Key](RECOVERY_KEY.md) |
| Included tools | [Included Tools](INCLUDED_TOOLS.md) |
