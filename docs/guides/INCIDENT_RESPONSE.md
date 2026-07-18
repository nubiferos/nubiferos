# NubiferOS Incident Response Guide

What to do when something goes wrong: a credential may be compromised, your
device is lost or stolen, or you suspect malware. This guide gives concrete
steps in priority order.

Two principles apply to every scenario:

1. **Cloud-side revocation comes first.** Anything you do on the local machine
   only affects the local machine. If a credential is compromised, the
   attacker is using it *from somewhere else* — kill it at the provider.
2. **Assume the worst supported by the evidence.** It is much cheaper to
   rotate a credential that wasn't actually stolen than to skip rotating one
   that was.

---

## Scenario 1: Suspected Credential Compromise

You pasted a secret key into the wrong window, committed it to a repo, saw
unfamiliar activity in a cloud account, or a machine holding your vault was
compromised.

### Step 1: Revoke at the cloud provider (do this first)

**AWS:**
```bash
# Deactivate the compromised access key immediately
aws iam update-access-key --access-key-id AKIA... --status Inactive --user-name <user>

# Then delete it once you've confirmed nothing legitimate depends on it
aws iam delete-access-key --access-key-id AKIA... --user-name <user>
```
Also revoke active sessions for any IAM roles the key could assume (IAM
console → role → "Revoke sessions"), since STS tokens issued before
revocation remain valid until they expire.

**Azure:**
- Rotate the client secret for compromised service principals
  (Entra admin center → App registrations → Certificates & secrets), and
  delete the old secret.
- For a compromised user account: reset the password and revoke refresh
  tokens:
  ```bash
  az rest --method POST \
    --url "https://graph.microsoft.com/v1.0/users/<user-id>/revokeSignInSessions"
  ```

**GCP:**
```bash
# Revoke local user credentials
gcloud auth revoke
gcloud auth application-default revoke

# Delete a compromised service account key
gcloud iam service-accounts keys delete <key-id> \
  --iam-account=<sa-name>@<project>.iam.gserviceaccount.com
```

### Step 2: Check for attacker activity

Before you consider the incident closed, look at what the credential *did*
while exposed:

- **AWS:** CloudTrail event history for the access key ID. Look especially
  for `CreateUser`, `CreateAccessKey`, `AttachUserPolicy`, `AssumeRole`, and
  activity in regions you don't use.
- **Azure:** Entra sign-in logs and Activity Log for the affected principal.
- **GCP:** Cloud Audit Logs (Admin Activity) for the service account.

Attackers commonly create *new* credentials as persistence. Revoke anything
you don't recognize.

### Step 3: Rotate and update the local vault

Once the old credential is dead:

```bash
# Remove the compromised entry from the vault
nubifer-creds delete --provider aws --account-id 123456789012

# Create a new key at the provider, then store it
nubifer-creds add --provider aws --account-id 123456789012 --account-name "Production"

# Verify the new credential works
nubifer-creds test --provider aws --account-id 123456789012
```

Repeat `nubifer-creds list` and audit **every** stored credential — if the
compromise vector was the machine itself (not a single pasted key), treat all
of them as exposed and rotate all of them.

### Step 4: If your GPG key may be compromised

The vault is only as strong as your GPG key. If an attacker had root on your
machine or captured your GPG passphrase, assume the vault contents are
readable (see [Credential Security](../CREDENTIAL_SECURITY.md) for the trust
model):

1. Rotate every credential in the vault (cloud-side first, as above).
2. Generate a new GPG key and re-initialize pass with it
   ([GPG Setup Guide](GPG_SETUP_GUIDE.md)).
3. Revoke the old key if it was published anywhere.

---

## Scenario 2: Lost or Stolen Device

### What you're protected against

If the machine was **powered off**, LUKS full disk encryption protects
everything on disk — including your GPG-encrypted vault — as long as your
passphrase is strong. This is the primary scenario the encryption is designed
for. See [Security Summary](../SECURITY_SUMMARY.md).

### What you're not protected against

Be honest with yourself about the machine's state when it was lost:

- **Suspended (sleep):** the LUKS key was in RAM. Treat the disk as
  potentially readable.
- **Powered on and unlocked:** treat everything on it as exposed.
- **Weak passphrase:** LUKS1 uses PBKDF2, which is GPU-crackable for short
  passphrases. If yours was short, don't rely on the encryption.

### Response steps

1. **Revoke cloud credentials remotely.** From any other machine, follow
   Scenario 1, Step 1 for every credential that was in the vault. Do this
   even if the machine was powered off — defense in depth costs you an hour;
   a wrong assumption costs you an account.
2. **Revoke active sessions** — SSO sessions, STS tokens, and cached OAuth
   tokens on the device may still be valid even after key rotation.
3. **Check audit logs** (Scenario 1, Step 2) over the following days for use
   of anything you missed.
4. **Rotate secondary credentials** that lived outside the vault: SSH keys
   in `~/.ssh`, git tokens, API tokens in application configs.
5. **Your recovery key is unaffected** — it's stored offline, not on the
   device. Keep it safe; you'll want it when you reinstall. If a copy of the
   recovery key was lost *with* the device (which
   [Recovery Key System](RECOVERY_KEY.md) explicitly tells you not to do),
   treat the disk as unencrypted.
6. If the device reappears, **do not trust it**. Reinstall from a verified
   ISO before using it again — you cannot rule out tampering while it was
   out of your control.

---

## Scenario 3: Suspected Malware

Unexpected processes, unexplained network traffic, modified files, or a tool
you now believe was malicious.

### Immediate containment

1. **Disconnect from the network** (unplug Ethernet, disable Wi-Fi). This
   cuts off exfiltration and command-and-control.
2. **Do not type any passphrases** on the machine from this point on — not
   your LUKS passphrase, not your GPG passphrase, not cloud passwords. A
   keylogger captures everything.
3. **Do not "clean" and continue.** Malware removal on a general-purpose OS
   is unreliable; you cannot prove a negative. Plan to reinstall.

### Assess and revoke

4. From a **different, trusted machine**, revoke and rotate all cloud
   credentials that were in the vault (Scenario 1). If malware ran as your
   user while your GPG key was cached by gpg-agent, it could have read vault
   entries.
5. Check cloud audit logs for activity you didn't perform.
6. Note what you observed (process names, file paths, when it started, what
   you installed recently) before wiping — it's useful for understanding the
   entry vector, and for a report if the vector was NubiferOS itself.

### Recover

7. **Reinstall from a verified ISO.** Verify the GPG signature before
   installing — see [Security Scanning](../SECURITY_SCANNING.md).
8. Set a **new** LUKS passphrase and generate a **new** GPG key during
   setup. Don't restore either from the compromised machine.
9. Restore data only from backups you trust, and only data files — not
   scripts, binaries, or shell configs from the compromised system.
10. Re-add credentials to the fresh vault using the *new* keys created
    during rotation.

Reality check: workspace isolation (Firejail) limits what a sandboxed cloud
CLI can touch, but it is not a malware containment system, and NubiferOS does
not claim to stop malware you install and run yourself. See
[Security Non-Goals](../SECURITY_NON_GOALS.md).

---

## Scenario 4: Suspicious Cloud Account Activity (No Local Signs)

If the anomaly is only in the cloud (unfamiliar API calls, new resources,
billing spike) and your workstation shows no signs of compromise:

1. Follow your organization's cloud incident process first — this is
   primarily a cloud incident, not a workstation incident.
2. Rotate the credentials involved (Scenario 1) since credential theft is the
   most common cause.
3. Only treat the workstation as compromised if the evidence points there
   (e.g., an API call that could only have come from a key that never left
   your vault).

Cloud-side incident response is out of scope for NubiferOS — see
[Security Non-Goals](../SECURITY_NON_GOALS.md).

---

## Reporting Security Issues in NubiferOS

If you believe the incident was caused by a vulnerability in NubiferOS itself
(the installer, credential manager, workspace isolation, build pipeline, or
default configuration):

- **Email:** security@nubiferos.org
- **Include:** description, reproduction steps, potential impact, and any
  logs or evidence you preserved.
- **Do not** open a public GitHub issue for exploitable vulnerabilities —
  we follow coordinated disclosure.

Full policy, scope, and response timelines: [SECURITY.md](../../SECURITY.md)
at the repository root. Issues in third-party tools (aws/az/gcloud CLIs),
upstream Debian packages, or cloud providers should be reported to those
projects directly.

---

## Preparation Checklist (Before You Need This Guide)

Incident response is mostly determined by what you did beforehand:

- [ ] Recovery key created and stored offline in two locations
      ([Recovery Key System](RECOVERY_KEY.md))
- [ ] You can log in to each cloud provider's console from a second device
      (to revoke credentials if your primary machine is gone)
- [ ] `nubifer-creds list` output is current — you know exactly which
      credentials exist and would need rotation
- [ ] Static keys are the exception; SSO/short-lived credentials are the rule
      ([Security Best Practices](SECURITY_BEST_PRACTICES.md))
- [ ] Audit logging (CloudTrail / Entra logs / Cloud Audit Logs) is enabled
      in your cloud accounts
- [ ] Backups of important data exist somewhere other than this machine

---

## Related Documentation

- [Security Best Practices](SECURITY_BEST_PRACTICES.md) — reduce the odds of needing this guide
- [Credential Security](../CREDENTIAL_SECURITY.md) — how the vault protects credentials, and its limits
- [Recovery Key System](RECOVERY_KEY.md) — recovering access to your own machine
- [Threat Model](../THREAT_MODEL.md) — attack scenarios NubiferOS is designed for
- [Security Non-Goals](../SECURITY_NON_GOALS.md) — what's explicitly out of scope
- [SECURITY.md](../../SECURITY.md) — vulnerability reporting policy
