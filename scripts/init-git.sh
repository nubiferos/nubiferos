#!/bin/bash
# Initialize Git repository for NubiferOS

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "Initializing Git repository for NubiferOS..."
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git first."
    exit 1
fi

# Check if already a git repository
if [ -d ".git" ]; then
    echo "Git repository already initialized."
    echo ""
    git status
    exit 0
fi

# Initialize git repository
echo "Creating git repository..."
git init

# Add all files
echo "Adding files to git..."
git add .

# Create initial commit
echo "Creating initial commit..."
git commit -m "Initial commit: NubiferOS project structure

- Set up build system and project structure
- Created directory structure for components, configs, installer
- Added build configuration with security settings
- Created documentation (README, CONTRIBUTING, LICENSE, CHANGELOG)
- Added validation scripts
- Configured version control with .gitignore

Requirements: 11.1, 11.2"

echo ""
echo "Git repository initialized successfully!"
echo ""
echo "Next steps:"
echo "1. Create a remote repository (e.g., on GitHub)"
echo "2. Add remote: git remote add origin <repository-url>"
echo "3. Push to remote: git push -u origin main"
echo ""
echo "Or rename branch to main if needed:"
echo "  git branch -M main"
