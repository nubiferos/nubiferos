# Workspace & Virtual Desktop Hardening Research

Research on open source projects for managing and hardening virtual desktops and workspaces for NubiferOS.

## Overview

NubiferOS needs secure workspace isolation to prevent credential leakage and accidental cross-account operations. This document surveys open source projects that could enhance our workspace security.

---

## 1. Firejail - Application Sandboxing

**Project**: https://github.com/netblue30/firejail  
**License**: GPL-2.0  
**Language**: C  
**Stars**: ~5.5k

### What It Does
- Sandboxes applications using Linux namespaces and seccomp-bpf
- Restricts filesystem access, network access, and system calls
- Can isolate applications per workspace

### Potential Use for NubiferOS
```bash
# Run cloud CLI in isolated sandbox per workspace
firejail --profile=aws-workspace-1 aws s3 ls

# Restrict network access to specific endpoints
firejail --net=none --whitelist=/home/user/.aws aws configure

# Prevent credential file access from other workspaces
firejail --private=/workspace1/.aws aws s3 ls
```

### Pros
- ✅ Mature project (10+ years)
- ✅ Lightweight (no VM overhead)
- ✅ Can create custom profiles per workspace
- ✅ Integrates with existing applications
- ✅ Prevents filesystem-based credential leakage

### Cons
- ⚠️ Requires careful profile configuration
- ⚠️ Can break applications if too restrictive
- ⚠️ Not as strong as VM isolation

### Integration Strategy
1. Create Firejail profiles for each cloud provider CLI
2. Automatically wrap CLI commands when workspace is active
3. Isolate credential directories per workspace
4. Restrict network access to cloud provider endpoints only

---

## 2. Bubblewrap - Container Sandboxing

**Project**: https://github.com/containers/bubblewrap  
**License**: LGPL-2.0+  
**Language**: C  
**Stars**: ~3.8k

### What It Does
- Lightweight sandboxing tool using Linux namespaces
- Used by Flatpak for application isolation
- Creates unprivileged containers without daemon

### Potential Use for NubiferOS
```bash
# Run workspace in isolated container
bwrap --ro-bind /usr /usr \
      --bind /workspace1 /home \
      --unshare-net \
      aws s3 ls

# Isolate environment variables
bwrap --clearenv \
      --setenv AWS_REGION us-east-1 \
      aws ec2 describe-instances
```

### Pros
- ✅ Very lightweight
- ✅ No daemon required
- ✅ Used by Flatpak (proven in production)
- ✅ Fine-grained control over namespaces
- ✅ Can isolate network, filesystem, IPC

### Cons
- ⚠️ Lower-level than Firejail (more manual setup)
- ⚠️ Requires understanding of Linux namespaces

### Integration Strategy
1. Wrap workspace activation with bubblewrap
2. Create isolated mount namespaces per workspace
3. Separate network namespaces for network isolation
4. Use for read-only workspaces (mount filesystems read-only)

---

## 3. AppArmor Profiles - Mandatory Access Control

**Project**: https://gitlab.com/apparmor/apparmor  
**License**: GPL-2.0  
**Language**: C, Python  
**Built into**: Ubuntu, Debian, SUSE

### What It Does
- Mandatory Access Control (MAC) system
- Restricts programs' capabilities with per-program profiles
- Kernel-level enforcement

### Potential Use for NubiferOS
```bash
# AppArmor profile for AWS CLI in workspace 1
/usr/local/bin/aws {
  # Allow reading workspace 1 credentials only
  /home/*/.config/nubifer/workspaces/workspace-1/** r,
  /home/*/.aws/workspace-1/** rw,
  
  # Deny access to other workspaces
  deny /home/*/.config/nubifer/workspaces/workspace-2/** rw,
  deny /home/*/.aws/workspace-2/** rw,
  
  # Allow network access
  network inet stream,
  network inet6 stream,
}
```

### Pros
- ✅ Kernel-level enforcement (can't be bypassed)
- ✅ Already included in Debian/Ubuntu
- ✅ Complements other isolation methods
- ✅ Prevents privilege escalation

### Cons
- ⚠️ Complex profile syntax
- ⚠️ Can break applications if misconfigured
- ⚠️ Requires root to modify profiles

### Integration Strategy
1. Create AppArmor profiles for all cloud CLIs
2. Restrict credential file access per workspace
3. Enforce network access policies
4. Prevent cross-workspace file access

---

## 4. systemd-nspawn - Lightweight Containers

**Project**: Part of systemd  
**License**: LGPL-2.1+  
**Language**: C  
**Built into**: Most modern Linux distros

### What It Does
- Lightweight container manager (like chroot on steroids)
- Full OS containers with namespace isolation
- Integrates with systemd for service management

### Potential Use for NubiferOS
```bash
# Run workspace in container
systemd-nspawn -D /var/lib/nubifer/workspace-1 \
               --bind-ro=/usr \
               --setenv=AWS_REGION=us-east-1 \
               /bin/bash

# Boot full workspace environment
systemd-nspawn -b -D /var/lib/nubifer/workspace-1
```

### Pros
- ✅ Built into systemd (no extra dependencies)
- ✅ Strong isolation (separate PID, network, mount namespaces)
- ✅ Can run full OS environment per workspace
- ✅ Integrates with systemd services

### Cons
- ⚠️ Heavier than Firejail/Bubblewrap
- ⚠️ Requires more setup (container images)
- ⚠️ May be overkill for simple workspace isolation

### Integration Strategy
1. Create lightweight container images per workspace
2. Use for high-security production workspaces
3. Integrate with systemd for workspace lifecycle management
4. Provide option for container-based vs. namespace-based isolation

---

## 5. Podman - Rootless Containers

**Project**: https://github.com/containers/podman  
**License**: Apache-2.0  
**Language**: Go  
**Stars**: ~23k

### What It Does
- Daemonless container engine (Docker alternative)
- Rootless containers (no root required)
- OCI-compliant container runtime

### Potential Use for NubiferOS
```bash
# Run workspace in rootless container
podman run --rm -it \
  --env-file /workspace1/.env \
  --volume /workspace1/.aws:/root/.aws:ro \
  nubiferos/workspace:aws \
  aws s3 ls

# Create workspace container image
podman build -t nubiferos/workspace:aws-prod -f Dockerfile.workspace
```

### Pros
- ✅ Strong isolation (full container)
- ✅ Rootless (no privilege escalation risk)
- ✅ Docker-compatible (familiar workflow)
- ✅ Can use container images for reproducibility
- ✅ Network isolation built-in

### Cons
- ⚠️ Heavier than namespace-based solutions
- ⚠️ Requires container images
- ⚠️ More complex setup

### Integration Strategy
1. Provide container-based workspace option (Phase 2)
2. Create workspace container images with cloud tools
3. Use for maximum isolation (production workspaces)
4. Enable workspace portability (export/import containers)

---

## 6. SELinux - Security-Enhanced Linux

**Project**: https://github.com/SELinuxProject/selinux  
**License**: GPL-2.0  
**Language**: C  
**Built into**: RHEL, Fedora, CentOS

### What It Does
- Mandatory Access Control (MAC) system (alternative to AppArmor)
- Fine-grained security policies
- Kernel-level enforcement

### Potential Use for NubiferOS
```bash
# SELinux policy for workspace isolation
type workspace1_t;
type workspace2_t;

# Workspace 1 can only access its own credentials
allow workspace1_t workspace1_creds_t:file { read write };
deny workspace1_t workspace2_creds_t:file { read write };
```

### Pros
- ✅ Very strong security model
- ✅ Kernel-level enforcement
- ✅ Fine-grained control

### Cons
- ⚠️ Complex policy language
- ⚠️ Not default on Debian/Ubuntu (AppArmor is)
- ⚠️ Steep learning curve
- ⚠️ Can break applications if misconfigured

### Integration Strategy
- Consider for RHEL/Fedora-based variant of NubiferOS
- Use AppArmor for Debian-based version (simpler)
- Provide SELinux policies as optional hardening

---

## 7. Linux Namespaces - Direct Kernel Features

**Project**: Built into Linux kernel  
**License**: GPL-2.0  
**Documentation**: https://man7.org/linux/man-pages/man7/namespaces.7.html

### What It Does
- Kernel feature for resource isolation
- Types: PID, Network, Mount, UTS, IPC, User, Cgroup
- Foundation for containers and sandboxing

### Potential Use for NubiferOS
```bash
# Create isolated workspace with namespaces
unshare --pid --net --mount --uts --ipc --fork \
  --mount-proc \
  /bin/bash

# Run workspace with network namespace
ip netns add workspace1
ip netns exec workspace1 aws s3 ls
```

### Pros
- ✅ Built into kernel (no dependencies)
- ✅ Foundation of all container technologies
- ✅ Very flexible
- ✅ Can combine with other tools

### Cons
- ⚠️ Low-level (requires manual setup)
- ⚠️ Complex to use directly
- ⚠️ Better to use higher-level tools (Firejail, Bubblewrap)

### Integration Strategy
- Use indirectly through Firejail or Bubblewrap
- Understand for debugging and advanced configurations
- Document namespace architecture for developers

---

## 8. Qubes OS Approach - VM-Based Isolation

**Project**: https://www.qubes-os.org/  
**License**: GPL-2.0  
**Language**: Python, C

### What It Does
- Security-focused OS using Xen hypervisor
- Each application runs in separate VM (qube)
- Strong isolation through virtualization

### Potential Use for NubiferOS
- Inspiration for architecture, not direct integration
- Each workspace could be a lightweight VM
- Use KVM/QEMU for VM-based workspaces

### Pros
- ✅ Strongest isolation (hardware virtualization)
- ✅ Proven security model
- ✅ Complete separation of workspaces

### Cons
- ⚠️ Heavy resource usage (full VMs)
- ⚠️ Complex architecture
- ⚠️ Slower than namespace-based isolation
- ⚠️ Requires significant RAM

### Integration Strategy
- Phase 3: Optional VM-based workspace mode
- For ultra-high-security environments
- Use lightweight VMs (Firecracker, Cloud Hypervisor)
- Provide as alternative to namespace-based isolation

---

## 9. Firecracker - Lightweight VMs

**Project**: https://github.com/firecracker-microvm/firecracker  
**License**: Apache-2.0  
**Language**: Rust  
**Stars**: ~25k  
**By**: Amazon (AWS Lambda uses this)

### What It Does
- Lightweight virtual machine monitor (VMM)
- Boots VMs in <125ms
- Minimal memory footprint (~5MB per VM)
- Designed for serverless and container workloads

### Potential Use for NubiferOS
```bash
# Run workspace in microVM
firectl --kernel=/boot/vmlinux \
        --root-drive=/workspace1.ext4 \
        --memory=512 \
        --cpus=1

# Ultra-fast workspace switching with microVMs
```

### Pros
- ✅ VM-level isolation with container-like speed
- ✅ Very lightweight (5MB overhead)
- ✅ Fast boot times (<125ms)
- ✅ Used in production by AWS Lambda
- ✅ Strong security (KVM-based)

### Cons
- ⚠️ Requires KVM support
- ⚠️ More complex than namespaces
- ⚠️ Still heavier than pure namespace isolation

### Integration Strategy
- Phase 2/3: Optional microVM-based workspaces
- For high-security production environments
- Balance between VM security and container speed
- Use for workspaces requiring strongest isolation

---

## 10. gVisor - Application Kernel

**Project**: https://github.com/google/gvisor  
**License**: Apache-2.0  
**Language**: Go  
**Stars**: ~15k  
**By**: Google

### What It Does
- User-space kernel for containers
- Intercepts system calls and implements them in user space
- Provides defense-in-depth for containers

### Potential Use for NubiferOS
```bash
# Run workspace with gVisor runtime
podman run --runtime=runsc \
  --env-file /workspace1/.env \
  nubiferos/workspace:aws

# Additional security layer for containers
```

### Pros
- ✅ Strong isolation (user-space kernel)
- ✅ Compatible with Docker/Podman
- ✅ Reduces kernel attack surface
- ✅ Used by Google Cloud Run

### Cons
- ⚠️ Performance overhead (system call interception)
- ⚠️ Not all system calls supported
- ⚠️ Complex architecture

### Integration Strategy
- Optional runtime for container-based workspaces
- Use when maximum security is required
- Combine with Podman for rootless + gVisor security

---

## Recommended Architecture for NubiferOS

### Phase 1 (MVP) - Namespace-Based Isolation
**Tools**: Firejail + AppArmor

```
┌─────────────────────────────────────────┐
│         GNOME Desktop (Wayland)         │
├─────────────────────────────────────────┤
│  Virtual Desktop 1  │  Virtual Desktop 2│
│  ┌───────────────┐  │  ┌──────────────┐│
│  │ AWS Workspace │  │  │Azure Workspace││
│  │ (Firejail)    │  │  │ (Firejail)   ││
│  └───────────────┘  │  └──────────────┘│
├─────────────────────────────────────────┤
│         AppArmor Profiles               │
│  (Credential Access Control)            │
├─────────────────────────────────────────┤
│         Linux Kernel                    │
└─────────────────────────────────────────┘
```

**Benefits**:
- Lightweight (no VM overhead)
- Fast workspace switching
- Good security for most use cases
- Easy to implement

### Phase 2 - Container-Based Isolation
**Tools**: Podman (rootless) + AppArmor

```
┌─────────────────────────────────────────┐
│         GNOME Desktop (Wayland)         │
├─────────────────────────────────────────┤
│  Workspace 1        │  Workspace 2      │
│  ┌───────────────┐  │  ┌──────────────┐│
│  │ Podman        │  │  │ Podman       ││
│  │ Container     │  │  │ Container    ││
│  │ (Rootless)    │  │  │ (Rootless)   ││
│  └───────────────┘  │  └──────────────┘│
├─────────────────────────────────────────┤
│         AppArmor + SELinux              │
├─────────────────────────────────────────┤
│         Linux Kernel                    │
└─────────────────────────────────────────┘
```

**Benefits**:
- Stronger isolation than namespaces
- Reproducible (container images)
- Portable workspaces
- Still relatively lightweight

### Phase 3 - MicroVM-Based Isolation
**Tools**: Firecracker + Podman

```
┌─────────────────────────────────────────┐
│         GNOME Desktop (Wayland)         │
├─────────────────────────────────────────┤
│  Workspace 1        │  Workspace 2      │
│  ┌───────────────┐  │  ┌──────────────┐│
│  │ Firecracker   │  │  │ Firecracker  ││
│  │ MicroVM       │  │  │ MicroVM      ││
│  │ (5MB, <125ms) │  │  │ (5MB, <125ms)││
│  └───────────────┘  │  └──────────────┘│
├─────────────────────────────────────────┤
│         KVM Hypervisor                  │
├─────────────────────────────────────────┤
│         Linux Kernel                    │
└─────────────────────────────────────────┘
```

**Benefits**:
- VM-level isolation
- Fast boot times
- Minimal overhead
- Maximum security

---

## Implementation Recommendations

### Immediate (Phase 1)

1. **Firejail Integration**
   ```bash
   # Create Firejail profiles
   /etc/firejail/nubifer-aws.profile
   /etc/firejail/nubifer-azure.profile
   /etc/firejail/nubifer-gcp.profile
   
   # Wrap CLI commands
   alias aws='firejail --profile=nubifer-aws aws'
   alias az='firejail --profile=nubifer-azure az'
   alias gcloud='firejail --profile=nubifer-gcp gcloud'
   ```

2. **AppArmor Profiles**
   ```bash
   # Create profiles for cloud CLIs
   /etc/apparmor.d/usr.local.bin.aws
   /etc/apparmor.d/usr.local.bin.az
   /etc/apparmor.d/usr.local.bin.gcloud
   
   # Enforce workspace credential isolation
   ```

3. **Namespace Isolation**
   ```bash
   # Use unshare for network isolation
   # Separate mount namespaces per workspace
   ```

### Short-Term (Phase 2)

1. **Podman Integration**
   - Create workspace container images
   - Rootless containers for each workspace
   - Optional for high-security workspaces

2. **Bubblewrap**
   - Lightweight alternative to Firejail
   - Use for read-only workspaces

### Long-Term (Phase 3)

1. **Firecracker MicroVMs**
   - Optional VM-based isolation
   - For ultra-high-security environments
   - Fast enough for practical use

2. **gVisor Runtime**
   - Additional security layer for containers
   - Use with Podman for defense-in-depth

---

## Security Comparison

| Solution | Isolation Strength | Performance | Complexity | Resource Usage |
|----------|-------------------|-------------|------------|----------------|
| Firejail | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | Low |
| Bubblewrap | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Low |
| AppArmor | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Minimal |
| systemd-nspawn | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Medium |
| Podman | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Medium |
| Firecracker | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Medium |
| gVisor | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | Medium |
| Qubes OS | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | High |

---

## Conclusion

**Recommended Approach**:

1. **Start with Firejail + AppArmor** (Phase 1)
   - Good balance of security and usability
   - Lightweight and fast
   - Easy to implement
   - Sufficient for most use cases

2. **Add Podman option** (Phase 2)
   - For users requiring stronger isolation
   - Container-based workspaces
   - Reproducible environments

3. **Consider Firecracker** (Phase 3)
   - For ultra-high-security environments
   - VM-level isolation with minimal overhead
   - Fast enough for practical use

This layered approach provides:
- ✅ Security by default (Firejail + AppArmor)
- ✅ Options for higher security (Podman, Firecracker)
- ✅ Good performance (namespace-based by default)
- ✅ Flexibility (users choose isolation level)

---

**Next Steps**:
1. Create Firejail profiles for cloud CLIs
2. Write AppArmor profiles for workspace isolation
3. Integrate with nubifer-workspace manager
4. Test credential isolation
5. Document security architecture

**References**:
- Firejail: https://firejail.wordpress.com/
- AppArmor: https://apparmor.net/
- Podman: https://podman.io/
- Firecracker: https://firecracker-microvm.github.io/
- Linux Namespaces: https://man7.org/linux/man-pages/man7/namespaces.7.html
