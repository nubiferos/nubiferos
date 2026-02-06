# Legacy Python CLI Wrappers

These Python-based CLI wrappers were an earlier implementation that used D-Bus for credential injection.

## Why Legacy?

This approach was superseded by the bash wrappers in `components/workspace-manager/cli-wrappers/` which use `credential_process` instead of D-Bus.

The `credential_process` approach is:
- Simpler (no D-Bus service needed for credentials)
- More secure (credentials never touch environment variables)
- More compatible (works with standard AWS CLI credential_process)

## Current Implementation

The active CLI wrappers are in: `components/workspace-manager/cli-wrappers/`

They work by:
1. Creating a temp AWS config with `credential_process`
2. AWS CLI calls `/usr/local/bin/nubifer-aws-credential-helper`
3. Helper reads from `pass` (GPG-encrypted)
4. Credentials returned as JSON, exist only in memory

## To Restore

If Python wrappers are ever needed:
```bash
mv components/_LEGACY_cli-wrappers components/cli-wrappers
```
