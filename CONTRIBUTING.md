# Contributing to NubiferOS

Thank you for your interest in contributing to NubiferOS! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/nubiferos.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes thoroughly
6. Commit with clear messages: `git commit -m "Add feature: description"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

### Prerequisites

- Debian 12 or Ubuntu 22.04 LTS
- Python 3.10+
- Node.js 18+
- Go 1.21+ (optional)
- Docker or Podman

### Setting Up Development Environment

```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools \
    python3 python3-pip python3-venv nodejs npm golang

# Set up Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Install Node.js dependencies (for Resource Viewer)
cd components/resource-viewer
npm install
cd ../..
```

## Project Structure

See [README.md](README.md) for detailed project structure.

## Coding Standards

### Python

- Follow PEP 8 style guide
- Use type hints where appropriate
- Write docstrings for all public functions and classes
- Maximum line length: 100 characters
- Use `black` for code formatting
- Use `pylint` for linting

```bash
# Format code
black components/credential-manager/src/

# Lint code
pylint components/credential-manager/src/
```

### JavaScript/TypeScript

- Follow Airbnb JavaScript Style Guide
- Use ESLint for linting
- Use Prettier for formatting
- Prefer TypeScript over JavaScript for new code

```bash
# Format code
npm run format

# Lint code
npm run lint
```

### Bash

- Use shellcheck for linting
- Include error handling (`set -e`, `set -u`)
- Add comments for complex logic
- Use meaningful variable names

```bash
# Lint shell scripts
shellcheck build/*.sh
```

## Testing

### Running Tests

```bash
# Python component tests
pytest components/credential-manager/tests/
pytest components/context-manager/tests/

# JavaScript tests
cd components/resource-viewer
npm test

# Integration tests
./test/run-tests.sh
```

### Writing Tests

- Write unit tests for all new functionality
- Aim for >80% code coverage
- Include integration tests for component interactions
- Test error handling and edge cases

## Documentation

### Code Documentation

- Add docstrings to all Python functions and classes
- Add JSDoc comments to JavaScript/TypeScript functions
- Include usage examples in docstrings
- Document all configuration options

### User Documentation

- Update README.md for user-facing changes
- Add documentation to `docs/` directory
- Include screenshots for UI changes
- Update requirements and design documents if needed

## Security

### Security Guidelines

- Never commit credentials or secrets
- Use environment variables for sensitive configuration
- Follow principle of least privilege
- Validate all user input
- Use parameterized queries for database operations
- Keep dependencies up to date

### Reporting Security Issues

Please report security vulnerabilities privately to security@nubiferos.org. Do not open public issues for security problems.

## Component-Specific Guidelines

### Credential Manager

- All credentials must be encrypted at rest
- Use system keyring (libsecret) for storage
- Never log credential values
- Implement secure memory handling (mlock)
- Support credential rotation

### Context Manager

- Ensure workspace isolation is maintained
- Validate workspace configurations
- Handle D-Bus communication errors gracefully
- Test virtual desktop integration thoroughly

### Resource Viewer

- Minimize cloud API calls
- Implement proper error handling for API failures
- Cache data appropriately
- Optimize database queries
- Test offline functionality

### Context Indicator

- Keep UI updates lightweight
- Handle desktop environment differences
- Test on both GNOME and KDE (when supported)
- Ensure accessibility compliance

## Build System

### Modifying Build Scripts

- Test changes in a clean environment
- Verify ISO boots successfully
- Check all components are installed correctly
- Update build configuration documentation
- Test on both Debian and Ubuntu bases (if applicable)

### Adding New Packages

- Add to appropriate package list in `build/config.sh`
- Document why the package is needed
- Verify package availability in base repositories
- Test installation in clean environment

## Pull Request Process

1. **Before Submitting**:
   - Ensure all tests pass
   - Update documentation
   - Follow coding standards
   - Rebase on latest main branch
   - Write clear commit messages

2. **PR Description**:
   - Describe what changes were made and why
   - Reference related issues
   - Include screenshots for UI changes
   - List any breaking changes
   - Note any new dependencies

3. **Review Process**:
   - Address reviewer feedback promptly
   - Keep discussions focused and professional
   - Update PR based on feedback
   - Ensure CI checks pass

4. **Merging**:
   - PRs require at least one approval
   - All CI checks must pass
   - No merge conflicts
   - Squash commits if requested

## Commit Message Guidelines

Follow conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `security`: Security improvements

**Examples**:
```
feat(credential-manager): add OIDC authentication support

Implement OAuth2 flow for OIDC authentication with automatic
token refresh. Supports multiple identity providers.

Closes #123
```

```
fix(context-indicator): correct color coding for Azure workspaces

The indicator was showing AWS orange instead of Azure blue
for Azure workspaces due to incorrect provider detection.

Fixes #456
```

## Release Process

1. Update version numbers in:
   - `build/config.sh`
   - Component version files
   - Documentation

2. Update CHANGELOG.md

3. Create release tag: `git tag -a v1.0.0 -m "Release version 1.0.0"`

4. Build release ISO

5. Generate checksums and GPG signatures

6. Create GitHub release with:
   - Release notes
   - ISO download link
   - Checksums
   - GPG signature

## Getting Help

- Check existing documentation in `docs/`
- Search existing issues on GitHub
- Ask questions in GitHub Discussions
- Join our community chat (if available)

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project website (when available)

Thank you for contributing to NubiferOS!
