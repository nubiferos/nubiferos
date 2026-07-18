# NubiferOS Security Best Practices

A practical guide for day-to-day secure use of NubiferOS. This ties together the
individual security features into habits that actually protect your cloud
credentials and accounts.

NubiferOS gives you strong defaults — full disk encryption, GPG-encrypted
credential storage, workspace isolation — but those defaults only hold if you
use them correctly. This guide covers what to do, what not to do, and why.

For what NubiferOS deliberately does **not** protect against, read
[Security Non-Goals](../SECURITY_NON_GOALS.md). Knowing the limits is part of
using the system safely.

---

## 1. Passphrases

You have (at least) two passphrases that matter: your **LUKS disk passphrase**
and your **GPG key passphrase**. Each one is a single point of failure for a
different layer.

### Do

- **Use a long passphrase, not a complex password.** 4-6 random words
  (25+ characters) beats `P@ssw0rd123!`. NubiferOS uses LUKS1 with PBKDF2 for
  GRUB compatibility, which is *less* GPU-resistant than Argon2id — passphrase
  length is your main defense. See [Security Summary](../SECURITY_SUMMARY.md)
  for the details and trade-offs.
- **Use different passphrases** for LUKS and GPG. If one is captured (e.g., by
  a shoulder-surfer), the other layer still holds.
- **Set a passphrase on your GPG key.** The automated setup wizard can create
  a key without one for convenience — add one afterward. See
  [GPG Setup Guide](GPG_SETUP_GUIDE.md) for how.

### Don't

- Don't reuse your cloud provider account password for LUKS or GPG.
- Don't store passphrases in a file on the same machine they protect.
- Don't rely on TPM auto-unlock as a substitute for a strong passphrase —
  TPM unlock protects convenience, not against an attacker who boots your
  actual machine. See [LUKS + TPM Strategy](../LUKS_TPM_CLOUD_STRATEGY.md).

---

## 2. Recovery Key Hygiene

Your recovery key can unlock your disk and reset your password. Treat it like
a master key, because it is one.

- Store it **offline** (USB drive in a safe, printed copy in a locked drawer)
  — never on the encrypted machine itself, and never in cloud storage.
- Make two copies in separate physical locations.
- If a recovery key may have been exposed, remove it from the LUKS keyslot and
  generate a new one.

Full details: [Recovery Key System](RECOVERY_KEY.md).

---

## 3. Credential Hygiene

The credential manager (`nubifer-creds`) exists so that plaintext secrets never
sit in `~/.aws/credentials`, `~/.azure/`, or environment variables. Use it for
everything.

### Do

- **Prefer short-lived credentials over static keys.** Use AWS SSO / IAM
  Identity Center, Azure device-code login with MFA, and GCP user auth where
  possible. Static access keys should be the exception, not the rule. See
  [Credential Security](../CREDENTIAL_SECURITY.md) for per-provider guidance.
- **Store any static keys in the vault:**
  ```bash
  nubifer-creds add -t aws -n production
  ```
- **Audit what you have** periodically:
  ```bash
  nubifer-creds list
  aws sts get-caller-identity   # confirms the active workspace's credentials work
  ```
  Remove credentials for accounts you no longer use
  (`nubifer-creds remove cloud/aws/<name>`).
- **Rotate static keys on a schedule** (90 days is a common baseline):
  1. Create a new key at the cloud provider.
  2. Update the vault: `nubifer-creds remove cloud/aws/<name>`, then
     `nubifer-creds add -t aws -n <name>` with the new key.
  3. Clear any cached session tokens: `nubifer-creds token clear -t aws -n <name>`.
  4. Verify with `aws sts get-caller-identity`.
  5. Deactivate, then delete, the old key at the provider.
- **Verify migration cleanup.** If you imported credentials from existing
  CLI configs, confirm the plaintext originals are gone.

### Don't

- Don't export secrets into shell environment variables "just for one command"
  — they end up in shell history and process listings.
- Don't paste credentials into scripts, notes, or terminal scrollback you
  screen-share.
- Don't use production credentials from a workspace that isn't clearly
  labeled as production.

Note: credentials transmitted to cloud APIs are protected by signing schemes
(SigV4, OAuth 2.0) and TLS — the secret key itself is never sent over the
wire. See [Cloud API Authentication Security](../CLOUD_API_AUTHENTICATION_SECURITY.md)
if you want to understand what a network observer can and cannot see.

---

## 4. Workspace Hygiene

Most cloud incidents caused by operators are not exotic attacks — they are
"I thought I was in the dev account." Workspaces exist to prevent exactly
that.

### Do

- **One workspace per cloud account.** Never share a workspace across
  accounts or environments.
- **Name workspaces unambiguously**: `AWS Production`, not `work2`.
- **Check the context indicator before destructive commands.** The colored
  prompt tells you provider, account, and region. If it doesn't match your
  intent, stop.
- **Use read-only mode by default** in production workspaces:
  ```bash
  nubifer-workspace readonly   # or: nubifer-workspace ro
  ```
  Switch to write mode (`nubifer-workspace rw`) only for the duration of an
  intentional change, then switch back.
- **Switch explicitly**, and let the visual confirmation register before you
  type the next command:
  ```bash
  nubifer-workspace switch
  nubifer-workspace current
  ```

### Don't

- Don't run cloud CLI commands outside a workspace context.
- Don't leave a production workspace active in a terminal you've stopped
  paying attention to.
- Don't disable the shell integration to "clean up" your prompt — the prompt
  is the safety feature.

---

## 5. Keep the System Updated

Encryption does not help against a remotely exploitable vulnerability in a
package you never updated.

- Apply security updates promptly — `sudo apt update && sudo apt upgrade`,
  or use the update checker described in [Update Management](UPDATE_MANAGEMENT.md).
- Reboot when a kernel update requires it. A patched kernel on disk protects
  nothing while the old one is still running.
- Understand how NubiferOS ships security fixes and triages CVEs:
  [Security Update Process](../SECURITY_UPDATE_PROCESS.md).

---

## 6. Verify What You Install

- **Verify ISO signatures** before installing NubiferOS — every release is
  GPG-signed. Steps are in [Security Scanning](../SECURITY_SCANNING.md).
- **Run the local scanner** occasionally to check vulnerability and
  hardening status:
  ```bash
  nubifer-security-scan --all
  ```
- Use the Security Dashboard (`nubifer-dashboard`) for an at-a-glance view of
  firewall, encryption, and scan status.
- Be deliberate about third-party software. NubiferOS cannot protect you from
  a malicious tool you install and run yourself — see
  [Security Non-Goals](../SECURITY_NON_GOALS.md).

---

## 7. Physical Security

LUKS protects data **at rest** — meaning the machine is powered off. It does
not protect a running, unlocked session.

- **Power off** (don't just suspend) before leaving the machine unattended in
  an untrusted place. Suspend keeps the disk encryption key in RAM.
- **Lock your screen** for short absences, always.
- If your device is lost or stolen, follow the
  [Incident Response Guide](INCIDENT_RESPONSE.md) — encryption protects the
  data on the disk, but you should still revoke cloud credentials.

---

## 8. Know When You're Outside the Threat Model

NubiferOS is a hardened workstation for cloud engineers, not a universal
shield. It does not protect against phishing, a compromised cloud provider,
nation-state attackers, or hardware implants. If your situation involves any
of these, you need controls beyond the operating system.

- [Threat Model](../THREAT_MODEL.md) — what's in scope and why
- [Security Non-Goals](../SECURITY_NON_GOALS.md) — what's explicitly out

---

## Quick Checklist

| Habit | Frequency |
|-------|-----------|
| Apply security updates | Weekly, or when notified |
| Rotate static cloud keys | Every 90 days |
| Audit stored credentials (`nubifer-creds list`) | Monthly |
| Verify recovery key copies still exist and work | Quarterly |
| Run `nubifer-security-scan --all` | Monthly |
| Check workspace context before destructive commands | Every time |
| Power off before travel / unattended in untrusted places | Every time |

---

## Related Documentation

- [Incident Response Guide](INCIDENT_RESPONSE.md) — what to do when something goes wrong
- [Credential Security](../CREDENTIAL_SECURITY.md) — credential architecture and per-provider practices
- [Security Summary](../SECURITY_SUMMARY.md) — overview of all security layers
- [Recovery Key System](RECOVERY_KEY.md) — creating and using recovery keys
- [GPG Setup Guide](GPG_SETUP_GUIDE.md) — key generation and pass initialization
- [Security Update Process](../SECURITY_UPDATE_PROCESS.md) — how updates and CVE triage work
