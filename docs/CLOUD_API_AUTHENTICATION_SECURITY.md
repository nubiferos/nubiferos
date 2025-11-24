# Cloud API Authentication Security: How Credentials Are Transmitted

## TL;DR - The Good News

**Your access keys and secret keys are NEVER sent in plaintext over the wire.**

All major cloud providers (AWS, Azure, GCP, Oracle) use cryptographic signing protocols where:
1. API requests are made over **HTTPS (TLS 1.2+)** - encrypted transport
2. Credentials are used to **sign requests locally** - never transmitted
3. Only the **signature** is sent to the cloud provider
4. The provider verifies the signature using your public key

**Your Firejail wrapper doesn't make things less secure** - it just isolates the CLI process. The CLI still uses the same secure authentication protocols.

## How Cloud Authentication Actually Works

### AWS Signature Version 4 (SigV4)

AWS uses a sophisticated signing protocol where your secret key **never leaves your machine**.

#### Step-by-Step Process:

```
1. You run: aws s3 ls

2. AWS CLI reads credentials from ~/.aws/credentials
   Access Key: AKIAIOSFODNN7EXAMPLE
   Secret Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

3. CLI creates a canonical request:
   GET
   /
   
   host:s3.amazonaws.com
   x-amz-date:20231123T120000Z
   
   host;x-amz-date
   UNSIGNED-PAYLOAD

4. CLI creates a string to sign:
   AWS4-HMAC-SHA256
   20231123T120000Z
   20231123/us-east-1/s3/aws4_request
   <hash of canonical request>

5. CLI derives signing key (using secret key):
   kSecret = "AWS4" + SecretAccessKey
   kDate = HMAC-SHA256(kSecret, "20231123")
   kRegion = HMAC-SHA256(kDate, "us-east-1")
   kService = HMAC-SHA256(kRegion, "s3")
   kSigning = HMAC-SHA256(kService, "aws4_request")

6. CLI creates signature:
   signature = HMAC-SHA256(kSigning, string_to_sign)
   Result: 5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7

7. CLI sends HTTPS request with Authorization header:
   Authorization: AWS4-HMAC-SHA256 
   Credential=AKIAIOSFODNN7EXAMPLE/20231123/us-east-1/s3/aws4_request,
   SignedHeaders=host;x-amz-date,
   Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7

8. AWS receives request and:
   - Looks up your secret key using the access key
   - Performs the same signing process
   - Compares signatures
   - If they match, request is authenticated
```

#### What's Transmitted Over the Wire:

```
✅ Sent:
- Access Key ID (AKIAIOSFODNN7EXAMPLE) - public identifier
- Signature (5d672d79c15b...) - cryptographic hash
- Request details (timestamp, region, service)

❌ NOT Sent:
- Secret Access Key - NEVER transmitted
- Any plaintext credentials
```

#### Security Properties:

1. **Replay Protection**: Timestamp in signature prevents replay attacks
2. **Integrity**: Any modification to request invalidates signature
3. **Non-repudiation**: Only holder of secret key can create valid signature
4. **Forward Secrecy**: Each request has unique signature

### Azure Shared Key Authentication

Similar to AWS, Azure uses HMAC-SHA256 signing:

```
1. You run: az storage blob list

2. Azure CLI reads credentials
   Account Name: mystorageaccount
   Account Key: <base64-encoded-key>

3. CLI creates string to sign:
   GET\n
   \n
   \n
   \n
   \n
   \n
   \n
   \n
   \n
   \n
   \n
   \n
   x-ms-date:Thu, 23 Nov 2023 12:00:00 GMT\n
   x-ms-version:2021-08-06\n
   /mystorageaccount/mycontainer

4. CLI signs with account key:
   signature = Base64(HMAC-SHA256(AccountKey, StringToSign))

5. CLI sends HTTPS request:
   Authorization: SharedKey mystorageaccount:Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==

6. Azure verifies signature
```

**Account key never transmitted** - only the signature.

### GCP OAuth 2.0 / Service Account Keys

GCP uses JWT (JSON Web Tokens) signed with private keys:

```
1. You run: gcloud compute instances list

2. GCP CLI reads service account key (JSON file)
   {
     "type": "service_account",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...",
     "client_email": "my-sa@project.iam.gserviceaccount.com"
   }

3. CLI creates JWT header:
   {
     "alg": "RS256",
     "typ": "JWT"
   }

4. CLI creates JWT payload:
   {
     "iss": "my-sa@project.iam.gserviceaccount.com",
     "scope": "https://www.googleapis.com/auth/compute",
     "aud": "https://oauth2.googleapis.com/token",
     "exp": 1700745600,
     "iat": 1700742000
   }

5. CLI signs JWT with private key:
   signature = RSA-SHA256(private_key, base64(header) + "." + base64(payload))

6. CLI sends JWT to get access token:
   POST https://oauth2.googleapis.com/token
   {
     "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
     "assertion": "<signed-jwt>"
   }

7. GCP returns access token:
   {
     "access_token": "ya29.c.Kl6iB...",
     "token_type": "Bearer",
     "expires_in": 3600
   }

8. CLI uses access token for API calls:
   Authorization: Bearer ya29.c.Kl6iB...
```

**Private key never transmitted** - only the JWT signature and resulting access token.

## Transport Layer Security (TLS/HTTPS)

All cloud APIs require HTTPS, which provides:

### TLS 1.2+ Encryption

```
Client (your machine)          Cloud Provider
      |                              |
      |--- ClientHello ------------->|
      |<-- ServerHello --------------|
      |<-- Certificate ---------------|
      |<-- ServerKeyExchange ---------|
      |<-- ServerHelloDone -----------|
      |                              |
      |--- ClientKeyExchange ------->|
      |--- ChangeCipherSpec -------->|
      |--- Finished ----------------->|
      |<-- ChangeCipherSpec ---------|
      |<-- Finished -----------------|
      |                              |
      |=== Encrypted Channel ========|
      |                              |
      |--- Encrypted API Request --->|
      |<-- Encrypted API Response ---|
```

### What TLS Protects:

✅ **Confidentiality**: All data encrypted (AES-256-GCM typically)  
✅ **Integrity**: HMAC prevents tampering  
✅ **Authentication**: Server certificate verified  
✅ **Forward Secrecy**: Ephemeral keys (DHE/ECDHE)  

### What's Visible to Network Observers:

```
❌ Cannot See:
- Request body
- Request headers (including Authorization)
- Response body
- Credentials
- Signatures

✅ Can See:
- Destination IP address
- Destination hostname (via SNI)
- Amount of data transferred
- Timing of requests
```

## Your Firejail Wrapper's Impact

### What Firejail Does:

```
User runs: aws s3 ls
     ↓
Firejail wrapper intercepts
     ↓
Firejail creates isolated namespace
     ↓
Real AWS CLI runs in namespace
     ↓
AWS CLI reads credentials from isolated filesystem
     ↓
AWS CLI signs request (same as without Firejail)
     ↓
AWS CLI sends HTTPS request (same as without Firejail)
     ↓
Response received
```

### Security Impact:

**Firejail does NOT:**
- ❌ Intercept or modify credentials
- ❌ Decrypt HTTPS traffic
- ❌ Change authentication protocols
- ❌ Make requests less secure

**Firejail DOES:**
- ✅ Isolate credentials from other processes
- ✅ Prevent credential leakage to other workspaces
- ✅ Enforce read-only mode at filesystem level
- ✅ Limit blast radius if CLI is compromised

**Conclusion**: Firejail wrapper is **transparent to authentication** - it's purely filesystem/process isolation.

## Potential Security Concerns & Mitigations

### 1. Man-in-the-Middle (MITM) Attacks

**Threat**: Attacker intercepts HTTPS traffic and decrypts it.

**Mitigations**:
- ✅ TLS certificate pinning (some CLIs do this)
- ✅ Certificate validation (all CLIs do this)
- ✅ HSTS (HTTP Strict Transport Security)
- ✅ Use trusted networks (avoid public WiFi)

**NubiferOS Enhancement**:
```bash
# Verify TLS certificates are being validated
export AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```

### 2. Credential Theft from Memory

**Threat**: Malicious process reads credentials from CLI's memory.

**Mitigations**:
- ✅ Firejail PID namespace isolation
- ✅ Linux kernel memory protection (ASLR, DEP)
- ✅ Seccomp filters prevent ptrace

**NubiferOS Enhancement**:
```bash
# Firejail blocks memory inspection
seccomp
seccomp.drop ptrace,process_vm_readv,process_vm_writev
```

### 3. Credential Theft from Filesystem

**Threat**: Malicious process reads ~/.aws/credentials file.

**Mitigations**:
- ✅ Firejail mount namespace isolation
- ✅ File permissions (600)
- ✅ Workspace-specific credential directories

**NubiferOS Enhancement**:
```bash
# Each workspace has isolated credentials
~/.aws/workspace-abc123/  # Only accessible to workspace abc123
~/.aws/workspace-def456/  # Only accessible to workspace def456
```

### 4. Network Eavesdropping

**Threat**: Attacker sniffs network traffic.

**Mitigations**:
- ✅ TLS encryption (AES-256-GCM)
- ✅ Perfect Forward Secrecy (PFS)
- ✅ No credentials in transit (only signatures)

**NubiferOS Enhancement**:
```bash
# Optional: Restrict network to cloud endpoints only
net eth0
netfilter /etc/firejail/nubifer/aws-endpoints.net
```

### 5. DNS Spoofing

**Threat**: Attacker redirects DNS to malicious server.

**Mitigations**:
- ✅ DNSSEC validation
- ✅ TLS certificate validation
- ✅ Certificate pinning

**NubiferOS Enhancement**:
```bash
# Use secure DNS resolver
echo "nameserver 1.1.1.1" > /etc/resolv.conf  # Cloudflare DNS
echo "nameserver 8.8.8.8" >> /etc/resolv.conf  # Google DNS
```

## Additional Security Enhancements for NubiferOS

### 1. Credential Encryption at Rest

Encrypt credentials on disk:

```bash
# Use LUKS for full disk encryption (already recommended)
# Or encrypt credential files specifically

# Install gnupg
sudo apt-get install gnupg

# Encrypt credentials
gpg --symmetric --cipher-algo AES256 ~/.aws/credentials

# Decrypt when needed
gpg --decrypt ~/.aws/credentials.gpg > ~/.aws/credentials
chmod 600 ~/.aws/credentials
```

### 2. Temporary Credentials (STS)

Use short-lived credentials instead of long-lived keys:

```bash
# AWS STS example
aws sts get-session-token --duration-seconds 3600

# Returns temporary credentials valid for 1 hour
{
  "Credentials": {
    "AccessKeyId": "ASIAIOSFODNN7EXAMPLE",
    "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "SessionToken": "FwoGZXIvYXdzEBYaD...",
    "Expiration": "2023-11-23T13:00:00Z"
  }
}
```

**Benefits**:
- Credentials expire automatically
- Reduced impact if stolen
- Can be revoked centrally

### 3. MFA-Protected API Calls

Require MFA for sensitive operations:

```bash
# AWS example
aws s3 rm s3://production-bucket --recursive --mfa "arn:aws:iam::123456789012:mfa/user 123456"
```

### 4. Network Traffic Monitoring

Monitor for suspicious API calls:

```bash
# Log all API calls
export AWS_DEBUG=1

# Or use CloudTrail/Azure Monitor/GCP Cloud Audit Logs
# These log all API calls at the cloud provider level
```

### 5. Certificate Pinning

Pin cloud provider certificates:

```bash
# AWS certificate fingerprint
AWS_CERT_FINGERPRINT="SHA256:1234567890abcdef..."

# Verify on each connection
curl --pinnedpubkey "sha256//$AWS_CERT_FINGERPRINT" https://s3.amazonaws.com
```

## Testing Authentication Security

### Test 1: Verify HTTPS is Used

```bash
# Capture traffic with tcpdump
sudo tcpdump -i any -w /tmp/aws-traffic.pcap host s3.amazonaws.com &

# Run AWS command
aws s3 ls

# Stop capture
sudo killall tcpdump

# Analyze with Wireshark
wireshark /tmp/aws-traffic.pcap

# You should see:
# ✅ TLS handshake
# ✅ Encrypted application data
# ❌ NO plaintext credentials
```

### Test 2: Verify Credentials Not in Request

```bash
# Enable debug mode
aws s3 ls --debug 2>&1 | grep -i "secret\|password"

# Should NOT show secret key in output
# Only shows: "Using credentials from ~/.aws/credentials"
```

### Test 3: Verify Signature-Based Auth

```bash
# Capture HTTP headers
aws s3 ls --debug 2>&1 | grep "Authorization:"

# Should show:
# Authorization: AWS4-HMAC-SHA256 Credential=AKIA.../20231123/us-east-1/s3/aws4_request, SignedHeaders=..., Signature=...

# Note: Secret key is NOT in the Authorization header
```

### Test 4: Verify TLS Version

```bash
# Check TLS version used
openssl s_client -connect s3.amazonaws.com:443 -tls1_2

# Should succeed with TLS 1.2 or higher
# Should fail with TLS 1.0 or 1.1 (deprecated)
```

## Comparison: Authentication Security

| Method | Credentials Transmitted? | Encryption | Replay Protection | MFA Support |
|--------|-------------------------|------------|-------------------|-------------|
| **AWS SigV4** | ❌ No (signature only) | ✅ TLS 1.2+ | ✅ Timestamp | ✅ Yes |
| **Azure Shared Key** | ❌ No (signature only) | ✅ TLS 1.2+ | ✅ Timestamp | ✅ Yes |
| **GCP OAuth 2.0** | ❌ No (JWT only) | ✅ TLS 1.2+ | ✅ Expiration | ✅ Yes |
| **Basic Auth** | ⚠️ Yes (base64) | ⚠️ Depends | ❌ No | ❌ No |
| **API Key in URL** | ⚠️ Yes (plaintext) | ⚠️ Depends | ❌ No | ❌ No |

**All major cloud providers use secure authentication** - credentials are never transmitted.

## Summary

### What Happens When You Run `aws s3 ls`:

1. ✅ **Credentials read from disk** (isolated by Firejail)
2. ✅ **Request signed locally** (secret key never leaves machine)
3. ✅ **HTTPS connection established** (TLS 1.2+ encryption)
4. ✅ **Signature sent** (not credentials)
5. ✅ **AWS verifies signature** (using your stored secret key)
6. ✅ **Response encrypted** (TLS)

### Your Firejail Wrapper:

- ✅ **Does NOT** make authentication less secure
- ✅ **Does NOT** expose credentials
- ✅ **DOES** provide additional isolation
- ✅ **DOES** prevent credential leakage between workspaces

### Bottom Line:

**Your credentials are secure.** Cloud providers use industry-standard cryptographic protocols where:
- Credentials are used for signing, not transmission
- All traffic is encrypted with TLS 1.2+
- Signatures prevent replay and tampering
- Your Firejail wrapper adds isolation without compromising security

The only way credentials could be exposed is:
1. Malware on your machine (Firejail helps prevent this)
2. Compromised cloud provider (extremely unlikely)
3. Quantum computer breaking TLS (not yet possible)
4. Physical access to your machine (use full disk encryption)

## References

- [AWS Signature Version 4](https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html)
- [Azure Shared Key Authentication](https://docs.microsoft.com/en-us/rest/api/storageservices/authorize-with-shared-key)
- [GCP OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [TLS 1.3 RFC](https://tools.ietf.org/html/rfc8446)
- [OWASP API Security](https://owasp.org/www-project-api-security/)
