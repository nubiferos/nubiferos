# AWS Testing for NubiferOS

Automated ISO testing using AWS CodeBuild and QEMU.

## Quick Start

### Windows
```powershell
cd aws-testing
.\setup-codebuild.ps1
```

### Linux/Mac
```bash
cd aws-testing
./setup-codebuild.sh
```

## What This Does

Tests your ISO in AWS CodeBuild by:
1. Downloading ISO from S3
2. Running automated tests (pytest)
3. Booting ISO in QEMU
4. Verifying boot works
5. Reporting results

**Time:** 5-10 minutes  
**Cost:** ~$0.05 per test

## Documentation

- **[SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md)** - Complete solution overview
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick command reference
- **[WINDOWS_SETUP.md](WINDOWS_SETUP.md)** - Windows setup guide
- **[TESTING_STRATEGY.md](TESTING_STRATEGY.md)** - Overall testing strategy
- **[codebuild/README.md](codebuild/README.md)** - CodeBuild details

## Setup Scripts

| Platform | Script | Description |
|----------|--------|-------------|
| Windows | `setup-codebuild.ps1` | PowerShell setup |
| Linux/Mac | `setup-codebuild.sh` | Bash setup |

## Buildspecs

| File | Purpose |
|------|---------|
| `codebuild/test-iso-buildspec.yml` | Test ISO with QEMU ⭐ |
| `codebuild/import-iso-buildspec.yml` | Old broken import ❌ |
| `codebuild/import-iso-buildspec-packer.yml` | Build AMI with Packer |

## Directory Structure

```
aws-testing/
├── README.md                          # This file
├── SOLUTION_SUMMARY.md                # Complete solution
├── QUICK_REFERENCE.md                 # Quick commands
├── WINDOWS_SETUP.md                   # Windows guide
├── TESTING_STRATEGY.md                # Testing strategy
├── ISO_IMPORT_ISSUE.md                # Root cause analysis
├── PACKER_IMPLEMENTATION.md           # Packer guide (optional)
│
├── setup-codebuild.ps1                # Windows setup
├── setup-codebuild.sh                 # Linux setup
│
├── codebuild/
│   ├── README.md                      # CodeBuild docs
│   ├── test-iso-buildspec.yml         # Main buildspec ⭐
│   ├── import-iso-buildspec.yml       # Broken (don't use)
│   ├── import-iso-buildspec-packer.yml # Packer buildspec
│   └── deploy-instance-buildspec.yml  # Deploy test instance
│
├── packer/
│   ├── README.md                      # Packer docs
│   └── nubiferos-simple.pkr.hcl       # Packer template
│
└── terraform/                         # Infrastructure (optional)
    └── ...
```

## Common Tasks

### Trigger Build
```bash
aws codebuild start-build --project-name nubiferos-test-iso
```

### Watch Logs
```bash
aws logs tail /aws/codebuild/nubiferos-test-iso --follow
```

### Update ISO Path
```bash
aws codebuild update-project \
  --name nubiferos-test-iso \
  --environment "environmentVariables=[{name=ISO_KEY,value=NEW_PATH,type=PLAINTEXT}]"
```

## Support

- **Logs:** `aws logs tail /aws/codebuild/nubiferos-test-iso`
- **Docs:** See files above
- **Issues:** Check CloudWatch logs

## Related

- **Local Testing:** `../testing/` - Test ISO locally before CodeBuild
- **Build System:** `../build/` - ISO build scripts
- **Components:** `../components/` - NubiferOS components

---

**Recommended:** Use `test-iso-buildspec.yml` for fast, cheap ISO testing.
