# LUKS + TPM Cloud Strategy

**Status**: FUTURE IMPLEMENTATION

## Overview

NubiferOS uses LUKS full disk encryption. For cloud/VM deployments, we can leverage virtual TPM (vTPM) for automatic unlock while maintaining passphrase fallback.

## Cloud vTPM Support

| Platform | vTPM Support | How to Enable |
|----------|--------------|---------------|
| AWS EC2 | NitroTPM 2.0 | Enable at instance launch (Nitro instances: m5, c5, r5, t3, etc.) |
| Azure | vTPM 2.0 | Use "Trusted Launch" Gen2 VMs |
| GCP | vTPM 2.0 | Enable Shielded VM (default on Shielded images) |
| VMware/ESXi | vTPM 2.0 | vSphere 6.7+, requires VM encryption or Trust Authority |
| QEMU/KVM | swtpm | Software TPM emulation |
| VirtualBox | TPM 2.0 | Version 7.0+ |

## Proposed Implementation

### Boot Flow
```
1. Check for TPM 2.0 device
   ├─ TPM found → Attempt auto-unlock with sealed key
   │   ├─ Success → Boot continues
   │   └─ Failure → Fall back to passphrase prompt
   └─ No TPM → Passphrase prompt
```

### Key Components
- **clevis** + **tang** or **clevis-tpm2** for TPM binding
- **dracut** or **initramfs** hooks for early boot unlock
- Passphrase always works as fallback

### Build Variants (Future)

1. **Standard Build** (current)
   - LUKS with passphrase only
   - Works everywhere

2. **Cloud TPM Build** (future)
   - LUKS with TPM auto-unlock
   - Passphrase fallback
   - Ideal for cloud VMs with vTPM

## Caveats

- **Snapshots/Clones**: TPM state doesn't transfer - cloned VMs won't auto-unlock
- **AMI Creation**: May break TPM sealing; test thoroughly
- **Migration**: Live migration between hosts may invalidate TPM state
- **Recovery**: Always maintain passphrase recovery option

## Security Considerations

TPM sealing binds the encryption key to:
- The specific (virtual) hardware
- Boot measurements (PCR values)

This prevents:
- Offline attacks on stolen disk images
- Boot tampering detection

But remember: cloud provider admins can still access memory of running VMs. LUKS protects data at rest, not in use.

## References

- [AWS NitroTPM](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nitrotpm.html)
- [Azure Trusted Launch](https://docs.microsoft.com/azure/virtual-machines/trusted-launch)
- [GCP Shielded VMs](https://cloud.google.com/compute/shielded-vm/docs/shielded-vm)
- [clevis](https://github.com/latchset/clevis)
