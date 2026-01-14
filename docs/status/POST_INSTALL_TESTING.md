# NubiferOS Post-Installation Testing

## Overview

NubiferOS includes a comprehensive post-installation testing system that automatically verifies the system configuration after installation. This is similar to "smoke tests" in cloud deployments.

## What Gets Tested

### 1. System Installation (5 tests)
- System is Debian/Ubuntu based
- Systemd is running
- Network connectivity
- DNS resolution
- Sufficient disk space

### 2. Package Installation (8+ tests)
- Core tools (pass, gpg, jq, curl, git)
- Cloud CLIs (AWS, Azure, GCP) if installed
- Container tools if installed

### 3. NubiferOS Scripts (4 tests)
- nubifer-creds installed and executable
- nubifer-setup-wizard installed
- nubifer-update-checker installed
- install-ide-plugins installed

### 4. Browser Configuration (3+ tests)
- Firefox installed
- Bookmark file exists and is valid JSON
- Bookmark import test (headless)

### 5. Credential Management (5 tests)
- GPG key generation
- pass initialization
- Credential storage
- Credential retrieval
- Encryption verification

### 6. IDE Plugin System (3+ tests)
- IDE detection
- VS Code extension installation (if VS Code installed)
- Extension verification

### 7. Update Management (3 tests)
- Update checker functionality
- Version detection
- Tool enumeration

### 8. Security Configuration (4 tests)
- Firewall installed
- AppArmor installed
- fail2ban installed
- Secure file permissions

### 9. Documentation (4 tests)
- Documentation directory exists
- All required docs present

### 10. Integration Tests (1+ tests)
- Setup wizard functionality
- End-to-end workflows

## Enabling Test Mode

### During Installation

When installing NubiferOS, you'll see an option:

```
☐ Enable post-installation testing mode

Enable comprehensive testing after installation.
Tests will run automatically on first boot and
results will be saved to /var/log/nubifer-test-report.txt

Recommended for: QA testing, automated deployments, CI/CD
```

Check this box to enable test mode.

### After Installation

You can manually run tests anytime:

```bash
sudo /usr/local/bin/nubifer-post-install-tests
```

## Test Results

### Viewing Results

```bash
# View test report
cat /var/log/nubifer-test-report.txt

# View detailed log
cat /var/log/nubifer-post-install-tests.log

# Check if tests passed
echo $?  # 0 = pass, 1 = fail
```

### Example Report

```
NubiferOS Post-Installation Test Report
========================================
Date: 2024-01-15 10:30:45
Hostname: nubiferos-test
OS: NubiferOS 1.0 (Nimbus)
Kernel: 6.1.0-17-amd64

Test Results:
  Total: 45
  Passed: 43
  Failed: 0
  Skipped: 2

Status: PASS ✓

Detailed log: /var/log/nubifer-post-install-tests.log
```

## Use Cases

### 1. Quality Assurance Testing

Run tests after every build to verify:
- All components installed correctly
- Configuration is valid
- Integration works

```bash
# In CI/CD pipeline
./build-iso.sh --enable-tests
./test-iso.sh
# ISO boots, installs, runs tests automatically
```

### 2. Automated Deployments

Deploy NubiferOS to multiple machines and verify each:

```bash
# Deploy with test mode
deploy-nubiferos --test-mode

# Check results on each machine
ssh machine1 cat /var/log/nubifer-test-report.txt
ssh machine2 cat /var/log/nubifer-test-report.txt
```

### 3. Custom Builds

Verify custom configurations:

```bash
# Build custom ISO
./build-iso.sh --custom-config my-config.yaml --enable-tests

# Install and verify
# Tests run automatically on first boot
```

### 4. Troubleshooting

Diagnose installation issues:

```bash
# Run tests manually
sudo /usr/local/bin/nubifer-post-install-tests

# Review failures
grep FAIL /var/log/nubifer-post-install-tests.log
```

## Test Modes

### Automatic Mode (First Boot)

When test mode is enabled during installation:

1. System installs normally
2. On first boot, systemd service runs tests
3. Results saved to `/var/log/nubifer-test-report.txt`
4. Service disables itself after running

### Manual Mode

Run tests anytime:

```bash
# Run all tests
sudo /usr/local/bin/nubifer-post-install-tests

# Run with verbose output
sudo bash -x /usr/local/bin/nubifer-post-install-tests
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test NubiferOS Build

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build ISO with test mode
        run: |
          sudo ./build/build-iso.sh --enable-tests
      
      - name: Test ISO in VM
        run: |
          # Boot ISO in QEMU
          # Wait for installation
          # Check test results
          ./scripts/test-iso-in-vm.sh
      
      - name: Upload test results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: /var/log/nubifer-test-report.txt
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh './build/build-iso.sh --enable-tests'
            }
        }
        
        stage('Test') {
            steps {
                sh './scripts/test-iso-in-vm.sh'
            }
        }
        
        stage('Report') {
            steps {
                archiveArtifacts artifacts: '**/nubifer-test-report.txt'
                junit 'test-results.xml'
            }
        }
    }
}
```

## Customizing Tests

### Adding Custom Tests

Edit `/usr/local/bin/nubifer-post-install-tests`:

```bash
# Add custom test section
echo "11. Custom Tests" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "My custom test" "test -f /path/to/file"
run_test "Another test" "command -v my-tool"
```

### Skipping Tests

Set environment variables:

```bash
# Skip optional tests
export SKIP_BROWSER_TESTS=1
export SKIP_IDE_TESTS=1

sudo -E /usr/local/bin/nubifer-post-install-tests
```

### Test Timeouts

Tests have built-in timeouts:
- Browser tests: 10 seconds
- Extension installation: 30 seconds
- Network tests: 5 seconds

## Troubleshooting

### Tests Don't Run on First Boot

```bash
# Check if flag file exists
ls -la /etc/nubifer/run-post-install-tests

# Check service status
systemctl status post-install-test.service

# Check service is enabled
systemctl is-enabled post-install-test.service

# Manually enable
sudo systemctl enable post-install-test.service
sudo systemctl start post-install-test.service
```

### Tests Fail

```bash
# View detailed log
sudo cat /var/log/nubifer-post-install-tests.log

# Find failures
grep FAIL /var/log/nubifer-post-install-tests.log

# Run specific test manually
# (extract test command from script)
```

### Tests Take Too Long

```bash
# Check what's running
ps aux | grep nubifer-post-install-tests

# Check system resources
top
df -h
free -h
```

## Best Practices

### For Development

1. **Always enable test mode** during development
2. **Review test results** after each build
3. **Add tests** for new features
4. **Fix failures immediately**

### For Production

1. **Test in staging first** with test mode enabled
2. **Disable test mode** for production deployments
3. **Keep test scripts** for troubleshooting
4. **Document** any skipped tests

### For CI/CD

1. **Automate testing** in pipeline
2. **Fail builds** on test failures
3. **Archive results** for review
4. **Track metrics** over time

## Performance

### Test Duration

- Typical run time: 2-5 minutes
- With all optional tools: 5-10 minutes
- Minimal installation: 1-2 minutes

### Resource Usage

- CPU: Low (mostly I/O bound)
- Memory: < 100MB
- Disk: < 10MB for logs
- Network: Minimal (only for connectivity tests)

## Security Considerations

### Test Credentials

Tests use temporary credentials:
- GPG keys expire in 1 day
- Test passwords are random
- All test data is cleaned up

### Network Access

Tests require network for:
- Connectivity verification
- DNS resolution
- Package repository access (if testing updates)

### Permissions

Tests run as root to:
- Install packages
- Modify system configuration
- Access all files

## Support

### Documentation
- Test script: `/usr/local/bin/nubifer-post-install-tests`
- Service file: `/etc/systemd/system/post-install-test.service`
- Results: `/var/log/nubifer-test-report.txt`

### Troubleshooting
- GitHub Issues: https://github.com/nubiferos/nubiferos/issues
- Discord: https://discord.gg/nubiferos

---

**NubiferOS Version**: 1.0 (Nimbus)  
**Last Updated**: 2024-01-15
