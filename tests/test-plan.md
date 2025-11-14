# NubiferOS Testing Plan

## Overview

Comprehensive testing plan for all implemented features before proceeding to workspace management.

## Test Environment Setup

### Prerequisites
```bash
# Install testing dependencies
sudo apt-get install -y shellcheck python3-pytest jq curl

# Install pass for credential testing
sudo apt-get install -y pass gnupg

# Generate test GPG key
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: NubiferOS Test
Name-Email: test@nubiferos.local
Expire-Date: 0
%no-protection
%commit
EOF
```

## 1. IDE Plugin Installation Tests

### Test 1.1: Script Syntax Validation
```bash
# Check bash syntax
shellcheck configs/ide/install-ide-plugins.sh

# Expected: No errors
```

### Test 1.2: IDE Detection
```bash
# Test with no IDEs installed
./configs/ide/install-ide-plugins.sh --dry-run

# Test with VS Code installed
code --version
./configs/ide/install-ide-plugins.sh --dry-run

# Expected: Correctly detects installed IDEs
```

### Test 1.3: VS Code Extension Installation
```bash
# Install one extension manually
code --install-extension hashicorp.terraform

# Verify installation
code --list-extensions | grep hashicorp.terraform

# Expected: Extension installed successfully
```

### Test 1.4: Neovim Configuration Generation
```bash
# Run plugin installer
./configs/ide/install-ide-plugins.sh

# Check generated config
cat ~/.config/nvim/init.vim

# Expected: Valid vim configuration with plugins
```

### Test 1.5: Vim Configuration Generation
```bash
# Check generated config
cat ~/.vimrc

# Expected: Valid vim configuration with plugins
```

## 2. Browser Bookmarks Tests

### Test 2.1: JSON Validation
```bash
# Validate JSON syntax
jq empty configs/browser/firefox-bookmarks.json

# Expected: No errors
```

### Test 2.2: Bookmark Structure
```bash
# Check bookmark count
jq '.children | length' configs/browser/firefox-bookmarks.json

# Check for required sections
jq '.children[].title' configs/browser/firefox-bookmarks.json | grep -E "AWS|Azure|GCP|Infrastructure|Kubernetes"

# Expected: All major sections present
```

### Test 2.3: URL Validation (Sample)
```bash
# Test a few critical URLs
curl -I -s -o /dev/null -w "%{http_code}" https://console.aws.amazon.com/
curl -I -s -o /dev/null -w "%{http_code}" https://portal.azure.com/
curl -I -s -o /dev/null -w "%{http_code}" https://console.cloud.google.com/

# Expected: All return 200 or 30x (redirects)
```

### Test 2.4: Firefox Import (Manual)
```bash
# Start Firefox
firefox &

# Manual steps:
# 1. Bookmarks → Manage Bookmarks
# 2. Import and Backup → Import Bookmarks from JSON
# 3. Select configs/browser/firefox-bookmarks.json
# 4. Verify bookmarks appear in sidebar

# Expected: All bookmarks imported successfully
```

## 3. Credential Manager Tests

### Test 3.1: Script Syntax
```bash
# Check Python syntax
python3 -m py_compile components/credential-manager/nubifer-creds

# Expected: No syntax errors
```

### Test 3.2: Pass Installation Check
```bash
# Check pass is installed
which pass
pass --version

# Expected: pass installed and working
```

### Test 3.3: Initialize Pass
```bash
# Get GPG key ID
GPG_KEY=$(gpg --list-keys --with-colons | grep '^pub' | head -1 | cut -d: -f5)

# Initialize pass
pass init $GPG_KEY

# Verify initialization
ls -la ~/.password-store/

# Expected: .password-store directory created with .gpg-id file
```

### Test 3.4: Add AWS Credentials
```bash
# Add test credentials
./components/credential-manager/nubifer-creds add \
  --type aws \
  --name test-profile \
  --access-key-id AKIATEST123456789 \
  --secret-access-key test-secret-key-12345678901234567890 \
  --region us-west-2

# Expected: Credentials added successfully
```

### Test 3.5: List Credentials
```bash
# List all credentials
./components/credential-manager/nubifer-creds list

# Expected: Shows test-profile
```

### Test 3.6: Retrieve Credentials
```bash
# Get credentials via pass directly
pass show nubifer/default/cloud/aws/test-profile/access-key-id

# Expected: Returns AKIATEST123456789
```

### Test 3.7: Add API Token
```bash
# Add GitHub token
./components/credential-manager/nubifer-creds add \
  --type api \
  --name github \
  --token ghp_test1234567890abcdefghijklmnopqrst

# Verify
pass show nubifer/default/api/github/token

# Expected: Token stored and retrievable
```

### Test 3.8: Remove Credentials
```bash
# Remove test credentials
./components/credential-manager/nubifer-creds remove \
  --path cloud/aws/test-profile/access-key-id

# Verify removal
pass show nubifer/default/cloud/aws/test-profile/access-key-id

# Expected: Credential removed (command fails)
```

### Test 3.9: Audit Log
```bash
# Check audit log exists
cat ~/.nubifer/audit.log

# Expected: Log entries for ADD, ACCESS, REMOVE operations
```

## 4. Documentation Tests

### Test 4.1: Markdown Validation
```bash
# Check all markdown files for syntax errors
for file in docs/*.md; do
  echo "Checking $file"
  # Basic markdown validation (check for broken links)
  grep -o '\[.*\](.*\.md)' "$file" | while read link; do
    target=$(echo "$link" | sed 's/.*(\(.*\))/\1/')
    if [ ! -f "docs/$target" ] && [ ! -f "$target" ]; then
      echo "  ⚠️  Broken link: $link in $file"
    fi
  done
done

# Expected: No broken internal links
```

### Test 4.2: Documentation Completeness
```bash
# Check that all documented features have corresponding files
grep -r "nubifer-creds" docs/ | grep -v ".md:" | wc -l

# Check IDE plugin documentation
ls -la configs/ide/install-ide-plugins.sh
ls -la docs/IDE_PLUGINS.md

# Expected: All referenced files exist
```

## 5. Integration Tests

### Test 5.1: End-to-End Credential Flow
```bash
# 1. Initialize pass
pass init $(gpg --list-keys --with-colons | grep '^pub' | head -1 | cut -d: -f5)

# 2. Add AWS credentials
./components/credential-manager/nubifer-creds add \
  --type aws --name integration-test \
  --access-key-id AKIAINTEGRATION123 \
  --secret-access-key integration-secret-key

# 3. Retrieve and export
export AWS_ACCESS_KEY_ID=$(pass show nubifer/default/cloud/aws/integration-test/access-key-id)
export AWS_SECRET_ACCESS_KEY=$(pass show nubifer/default/cloud/aws/integration-test/secret-access-key)

# 4. Verify environment variables
echo $AWS_ACCESS_KEY_ID

# Expected: AKIAINTEGRATION123
```

### Test 5.2: IDE Plugin + Credential Integration
```bash
# 1. Install Terraform VS Code extension
code --install-extension hashicorp.terraform

# 2. Add Terraform Cloud token
./components/credential-manager/nubifer-creds add \
  --type api --name terraform-cloud \
  --token test-terraform-token

# 3. Verify both work
code --list-extensions | grep terraform
pass show nubifer/default/api/terraform-cloud/token

# Expected: Both extension and credentials available
```

## 6. Security Tests

### Test 6.1: File Permissions
```bash
# Check pass directory permissions
stat -c "%a %n" ~/.password-store/

# Check audit log permissions
stat -c "%a %n" ~/.nubifer/audit.log

# Expected: 
# - .password-store: 700
# - audit.log: 600 or 644
```

### Test 6.2: GPG Encryption Verification
```bash
# Check that credentials are actually encrypted
file ~/.password-store/nubifer/default/cloud/aws/*/access-key-id.gpg

# Try to read without GPG
cat ~/.password-store/nubifer/default/cloud/aws/*/access-key-id.gpg

# Expected: 
# - file: GPG encrypted data
# - cat: Binary/encrypted data (not plaintext)
```

### Test 6.3: Audit Log Integrity
```bash
# Add credential
./components/credential-manager/nubifer-creds add \
  --type api --name test-audit --token test123

# Check audit log
tail -1 ~/.nubifer/audit.log | grep "ADD"

# Expected: Audit entry created with timestamp, user, action
```

## 7. Performance Tests

### Test 7.1: Credential Retrieval Speed
```bash
# Time credential retrieval
time pass show nubifer/default/cloud/aws/test-profile/access-key-id

# Expected: < 0.1 seconds
```

### Test 7.2: IDE Plugin Installation Time
```bash
# Time plugin installation (dry run)
time ./configs/ide/install-ide-plugins.sh --dry-run

# Expected: < 5 seconds for detection
```

## 8. Error Handling Tests

### Test 8.1: Missing Pass Installation
```bash
# Temporarily rename pass
sudo mv /usr/bin/pass /usr/bin/pass.bak

# Try to use credential manager
./components/credential-manager/nubifer-creds list

# Restore pass
sudo mv /usr/bin/pass.bak /usr/bin/pass

# Expected: Clear error message about missing pass
```

### Test 8.2: Uninitialized Pass
```bash
# Remove pass store
rm -rf ~/.password-store/

# Try to add credential
./components/credential-manager/nubifer-creds add --type aws --name test

# Expected: Clear error message about uninitialized pass
```

### Test 8.3: Invalid Bookmark JSON
```bash
# Create invalid JSON
echo "{invalid json" > /tmp/test-bookmarks.json

# Try to validate
jq empty /tmp/test-bookmarks.json

# Expected: JSON parse error
```

## 9. Documentation Accuracy Tests

### Test 9.1: Command Examples
```bash
# Test all command examples from CREDENTIAL_SECURITY.md
# (Extract and run each bash code block)

# Example:
pass init <gpg-key-id>
pass insert aws/production/access-key-id

# Expected: All examples work as documented
```

### Test 9.2: Quick Reference Accuracy
```bash
# Test commands from QUICK_REFERENCE.md
nubifer-creds list
pass show nubifer/default/cloud/aws/test/access-key-id

# Expected: All commands work as documented
```

## 10. Cross-Platform Tests (If Applicable)

### Test 10.1: Different Desktop Environments
```bash
# Test on GNOME
# Test on KDE
# Test on XFCE

# Expected: Works on all major desktop environments
```

## Test Results Template

```markdown
## Test Results - [Date]

### Environment
- OS: Debian 12 / Ubuntu 22.04
- Desktop: GNOME / KDE / XFCE
- Shell: bash
- Python: 3.x
- pass: x.x.x

### Test Summary
- Total Tests: X
- Passed: X
- Failed: X
- Skipped: X

### Failed Tests
1. Test X.X: [Description]
   - Error: [Error message]
   - Fix: [Proposed fix]

### Issues Found
1. [Issue description]
   - Severity: High/Medium/Low
   - Component: [Component name]
   - Fix: [Proposed fix]

### Recommendations
1. [Recommendation]
2. [Recommendation]
```

## Automated Test Script

Create `tests/run-tests.sh`:
```bash
#!/bin/bash
# Automated test runner

set -e

echo "=========================================="
echo "NubiferOS Test Suite"
echo "=========================================="

# Test 1: Syntax checks
echo "Running syntax checks..."
shellcheck configs/ide/install-ide-plugins.sh
python3 -m py_compile components/credential-manager/nubifer-creds
jq empty configs/browser/firefox-bookmarks.json
echo "✓ Syntax checks passed"

# Test 2: File existence
echo "Checking file existence..."
test -f configs/ide/install-ide-plugins.sh
test -f components/credential-manager/nubifer-creds
test -f configs/browser/firefox-bookmarks.json
test -f docs/CREDENTIAL_SECURITY.md
test -f docs/IDE_PLUGINS.md
echo "✓ All files exist"

# Test 3: Permissions
echo "Checking permissions..."
test -x configs/ide/install-ide-plugins.sh
test -x components/credential-manager/nubifer-creds
echo "✓ Permissions correct"

# Test 4: Dependencies
echo "Checking dependencies..."
which pass || echo "⚠️  pass not installed"
which gpg || echo "⚠️  gpg not installed"
which jq || echo "⚠️  jq not installed"
echo "✓ Dependency check complete"

echo "=========================================="
echo "Basic tests passed!"
echo "Run manual tests from test-plan.md"
echo "=========================================="
```

## Next Steps After Testing

1. Document all issues found
2. Create GitHub issues for bugs
3. Fix critical issues
4. Update documentation based on findings
5. Create automated CI/CD tests
6. Proceed to workspace management implementation
