# NubiferOS Versioning Strategy

## Overview

NubiferOS follows semantic versioning (SemVer) after reaching 1.0.0 stable release. During development, we use a phased approach with alpha, beta, and release candidate stages.

## Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE]
```

- **MAJOR**: Incompatible API changes or major feature overhauls
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, security updates, backward compatible
- **PRERELEASE**: alpha, beta, rc (release candidate)

## Development Phases

### Phase 1: Alpha (0.x.x-alpha)

**Purpose**: Internal development and testing. Features are incomplete and may change significantly.

**Milestones**:

- **0.1.0-alpha** - First bootable ISO
  - [ ] ISO builds successfully
  - [ ] System boots to login screen
  - [ ] Basic GNOME desktop loads
  - [ ] Network connectivity works

- **0.2.0-alpha** - Core functionality verified
  - [ ] All cloud CLIs accessible (aws, az, gcloud)
  - [ ] IDEs launch successfully
  - [ ] Terminal and basic tools work
  - [ ] Critical boot issues resolved

- **0.3.0-alpha** - Workspace manager functional
  - [ ] Workspace switching works
  - [ ] Context isolation functional
  - [ ] Firejail integration working
  - [ ] Shell integration active

- **0.4.0-alpha** - Credential manager operational
  - [ ] Credential storage works
  - [ ] Credential retrieval works
  - [ ] Integration with cloud CLIs
  - [ ] Security features active

**Criteria for Beta**: All core features implemented and working, though bugs may exist.

---

### Phase 2: Beta (0.x.x-beta)

**Purpose**: External testing with early adopters. Feature complete but needs polish and bug fixes.

**⚠️ Repository Status**: Private repository until beta release. Alpha development is internal only.

**Milestones**:

- **0.5.0-beta** - First public beta (repository goes public)
  - [ ] All alpha features stable
  - [ ] Documentation complete
  - [ ] Installation guide tested
  - [ ] Known critical bugs fixed
  - [ ] Ready for external testers

- **0.6.0-beta** - Feedback iteration
  - [ ] User feedback incorporated
  - [ ] Performance optimizations
  - [ ] UI/UX improvements
  - [ ] Additional testing completed

- **0.7.0-beta** - Feature freeze
  - [ ] No new features
  - [ ] Focus on stability
  - [ ] Bug fixes only
  - [ ] Security hardening verified

- **0.8.0-beta** - Polish and refinement
  - [ ] All major bugs resolved
  - [ ] Performance acceptable
  - [ ] User experience smooth
  - [ ] Ready for RC

**Criteria for RC**: No known critical bugs, feature complete, stable for daily use.

---

### Phase 3: Release Candidate (0.9.x-rc)

**Purpose**: Final testing before stable release. Only critical bug fixes allowed.

**Milestones**:

- **0.9.0-rc1** - First release candidate
  - [ ] All beta issues resolved
  - [ ] Full test suite passes
  - [ ] Security audit complete
  - [ ] Documentation finalized

- **0.9.1-rc2** - Bug fixes from RC1 (if needed)
  - [ ] Critical bugs from RC1 fixed
  - [ ] Regression testing passed
  - [ ] No new issues introduced

- **0.9.x-rcN** - Additional RCs as needed
  - [ ] Continue until no critical issues found
  - [ ] Each RC must be stable for 1 week minimum

**Criteria for 1.0.0**: No critical bugs, stable for 2+ weeks, positive user feedback.

---

### Phase 4: Stable Release (1.0.0+)

**Purpose**: Production-ready releases following semantic versioning.

**Version Scheme**:

#### Major Versions (X.0.0)
- Breaking changes
- Major architectural changes
- Incompatible with previous versions
- Examples:
  - New base distribution (Debian 13)
  - Major desktop environment change
  - Breaking API changes

#### Minor Versions (1.X.0)
- New features (backward compatible)
- New cloud provider support
- New tools and utilities
- Enhanced functionality
- Examples:
  - Add Oracle Cloud support
  - New workspace features
  - Additional security features
  - New IDE integrations

#### Patch Versions (1.0.X)
- Bug fixes
- Security updates
- Tool version updates
- Performance improvements
- Examples:
  - Fix credential manager bug
  - Update AWS CLI version
  - Security patch
  - Performance optimization

---

## Release Naming

Each major/minor release has a codename based on cloud-related terms:

- **1.0 "Nimbus"** - First stable release
- **1.1 "Cirrus"** - TBD
- **1.2 "Stratus"** - TBD
- **2.0 "Cumulus"** - TBD

---

## Version Tracking

### Current Version
**0.1.0-alpha** (In Development)

### Version History

#### 0.1.0-alpha (2025-11-13) - First Build
- Initial ISO build
- GNOME desktop environment
- 70+ cloud tools installed
- AWS, Azure, GCP CLI support
- Terraform, Pulumi, Ansible
- Docker, Kubernetes tools
- Multiple IDEs (VS Code, IntelliJ, PyCharm, Eclipse)
- Security hardening (AppArmor, fail2ban, UFW)
- Workspace manager (basic)
- Credential manager (basic)

---

## Changelog Management

### During Alpha/Beta
- Keep informal notes in `CHANGELOG.md`
- Document major changes and fixes
- No strict format required

### After 1.0.0
- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Categorize changes:
  - Added
  - Changed
  - Deprecated
  - Removed
  - Fixed
  - Security

---

## Release Process

### Alpha/Beta Releases
1. Update version in `brand/brand.conf`
2. Build ISO
3. Test basic functionality
4. Document known issues
5. Tag in git: `v0.x.x-alpha`
6. Update CHANGELOG.md

### Stable Releases (1.0.0+)
1. Create release branch: `release/1.x`
2. Update version in `brand/brand.conf`
3. Update CHANGELOG.md
4. Full test suite
5. Security audit
6. Build final ISO
7. Generate checksums
8. Sign ISO (if GPG configured)
9. Tag in git: `v1.x.x`
10. Create GitHub release
11. Update documentation
12. Announce release

---

## Version Bumping Guidelines

### When to bump MAJOR (X.0.0)
- Breaking changes to APIs or interfaces
- Major architectural redesign
- Incompatible with previous versions
- Requires user migration

### When to bump MINOR (1.X.0)
- New features added
- New cloud provider support
- New major tools or capabilities
- Backward compatible changes

### When to bump PATCH (1.0.X)
- Bug fixes
- Security patches
- Tool version updates
- Documentation fixes
- Performance improvements

---

## Long-Term Support (LTS)

**Post 1.0.0 Strategy**:

- **LTS Releases**: Every 2 years (e.g., 2.0, 4.0, 6.0)
- **LTS Support**: 3 years of security updates
- **Regular Releases**: Every 6 months
- **Regular Support**: 1 year

Example timeline:
- 1.0 LTS (2026) - Supported until 2029
- 1.1 (2026) - Supported until 2027
- 1.2 (2027) - Supported until 2028
- 2.0 LTS (2028) - Supported until 2031

---

## Repository Access

**Alpha Phase (0.1.x - 0.4.x)**: Private repository, internal development only
**Beta Phase (0.5.x+)**: Public repository, open for external testing
**Stable (1.0.0+)**: Fully public with community contributions

## Current Focus

**Right now**: Get 0.1.0-alpha working!

Priority:
1. ✅ Build ISO successfully
2. ⏳ Boot and test
3. ⏳ Fix critical issues
4. ⏳ Verify core features
5. ⏳ Move to 0.2.0-alpha

Don't worry about formal versioning until we hit beta. Focus on making it work!

**Note**: Repository remains private during alpha development. We'll go public when we hit 0.5.0-beta.

---

## References

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Ubuntu Release Cycle](https://ubuntu.com/about/release-cycle)
- [Debian Release Process](https://www.debian.org/releases/)
