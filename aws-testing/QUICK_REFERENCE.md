# Quick Reference: ISO Testing

## Setup (One-Time)

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

## Daily Usage

### Trigger Build
```powershell
aws codebuild start-build --project-name nubiferos-test-iso
```

### Watch Logs
```powershell
aws logs tail /aws/codebuild/nubiferos-test-iso --follow
```

### Check Status
```powershell
aws codebuild batch-get-builds --ids BUILD_ID
```

## Test Locally (Before CodeBuild)

### Quick Test
```bash
cd testing
pytest test-iso-pytest.py -v
```

### Manual Test
```bash
./test-iso-locally.sh
```

## Common Tasks

### Change ISO Path
```powershell
aws codebuild update-project `
  --name nubiferos-test-iso `
  --environment "environmentVariables=[{name=ISO_KEY,value=NEW_PATH,type=PLAINTEXT}]"
```

### List Recent Builds
```powershell
aws codebuild list-builds-for-project --project-name nubiferos-test-iso
```

### Delete Project
```powershell
aws codebuild delete-project --name nubiferos-test-iso
```

## File Locations

- **Buildspec:** `aws-testing/codebuild/test-iso-buildspec.yml`
- **Setup:** `aws-testing/setup-codebuild.ps1`
- **Tests:** `testing/test-iso-pytest.py`
- **Docs:** `aws-testing/WINDOWS_SETUP.md`

## Costs

- **Per test:** ~$0.05
- **Per month (10 tests):** ~$0.50

## Time

- **Setup:** 10 minutes (one-time)
- **Per test:** 5-10 minutes

## Support

- **Logs:** `aws logs tail /aws/codebuild/nubiferos-test-iso`
- **Docs:** `aws-testing/SOLUTION_SUMMARY.md`
- **Help:** `aws-testing/WINDOWS_SETUP.md`
