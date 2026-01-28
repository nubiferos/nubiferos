#!/bin/bash
# Install and configure browsers for NubiferOS
# Part of system customization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Firefox (primary browser)
install_firefox() {
    echo "Installing Firefox..."
    apt-get install -y firefox-esr
    
    # Install Firefox Multi-Account Containers extension
    # This will be done via policy file
    
    echo "✓ Firefox installed"
}

# Install Brave (optional browser)
install_brave() {
    echo "Installing Brave..."
    
    # Add Brave repository
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
        tee /etc/apt/sources.list.d/brave-browser-release.list
    
    apt-get update
    apt-get install -y brave-browser
    
    echo "✓ Brave installed"
}

# Configure Firefox with hardening
configure_firefox() {
    echo "Configuring Firefox..."
    
    # Create Firefox policy directory
    mkdir -p /etc/firefox/policies
    
    # Copy hardening configuration
    cp "${SCRIPT_DIR}/firefox-hardening.js" /etc/firefox/syspref.js
    
    # Create Firefox policies
    cat > /etc/firefox/policies/policies.json << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFirefoxAccounts": false,
    "DontCheckDefaultBrowser": true,
    "EnableTrackingProtection": {
      "Value": true,
      "Locked": false,
      "Cryptomining": true,
      "Fingerprinting": true
    },
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      },
      "@testpilot-containers": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi"
      }
    },
    "FirefoxHome": {
      "Pocket": false,
      "Snippets": false
    },
    "Homepage": {
      "StartPage": "none"
    },
    "NoDefaultBookmarks": false,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "Preferences": {
      "privacy.userContext.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "privacy.userContext.ui.enabled": {
        "Value": true,
        "Status": "locked"
      }
    },
    "SearchEngines": {
      "Default": "DuckDuckGo"
    }
  }
}
EOF
    
    echo "✓ Firefox configured"
}

# Import bookmarks via Firefox policy
import_bookmarks() {
    echo "Importing bookmarks via Firefox policy..."
    
    # Copy bookmarks JSON for reference
    mkdir -p /usr/share/nubifer/browser
    cp "${SCRIPT_DIR}/firefox-bookmarks.json" /usr/share/nubifer/browser/
    
    # Convert our bookmarks JSON to Firefox ManagedBookmarks policy format
    python3 << 'PYTHON_SCRIPT'
import json
import os

# Read our bookmarks
with open('/usr/share/nubifer/browser/firefox-bookmarks.json') as f:
    bookmarks = json.load(f)

def convert_to_managed(children):
    """Convert our format to Firefox ManagedBookmarks format"""
    result = []
    for item in children:
        if 'children' in item:
            # It's a folder
            result.append({
                "toplevel_name": item['title'],
                "children": convert_children(item['children'])
            })
        elif 'url' in item:
            # It's a bookmark
            result.append({
                "name": item['title'],
                "url": item['url']
            })
    return result

def convert_children(children):
    """Convert child items"""
    result = []
    for item in children:
        if 'children' in item:
            result.append({
                "name": item['title'],
                "children": convert_children(item['children'])
            })
        elif 'url' in item:
            result.append({
                "name": item['title'],
                "url": item['url']
            })
    return result

# Build managed bookmarks array
managed = []
for folder in bookmarks.get('children', []):
    if 'children' in folder:
        managed.append({
            "toplevel_name": folder['title'],
            "children": convert_children(folder['children'])
        })

# Read existing policy
policy_file = '/etc/firefox/policies/policies.json'
with open(policy_file) as f:
    policy = json.load(f)

# Add ManagedBookmarks
policy['policies']['ManagedBookmarks'] = managed

# Write updated policy
with open(policy_file, 'w') as f:
    json.dump(policy, f, indent=2)

print(f"Added {len(managed)} bookmark folders to Firefox policy")
PYTHON_SCRIPT
    
    echo "✓ Bookmarks imported via Firefox policy"
}

# Create container configuration
configure_containers() {
    echo "Configuring Multi-Account Containers..."
    
    # Create container configuration
    mkdir -p /usr/share/nubifer/browser/containers
    
    cat > /usr/share/nubifer/browser/containers/containers.json << 'EOF'
{
  "version": 1,
  "containers": [
    {
      "name": "AWS",
      "icon": "briefcase",
      "color": "orange",
      "colorCode": "#FF9900",
      "userContextId": 1
    },
    {
      "name": "Azure",
      "icon": "briefcase",
      "color": "blue",
      "colorCode": "#0078D4",
      "userContextId": 2
    },
    {
      "name": "GCP",
      "icon": "briefcase",
      "color": "red",
      "colorCode": "#EA4335",
      "userContextId": 3
    },
    {
      "name": "Personal",
      "icon": "fingerprint",
      "color": "green",
      "colorCode": "#37ADFF",
      "userContextId": 4
    }
  ]
}
EOF
    
    echo "✓ Container configuration created"
}

# Main installation
main() {
    echo "=========================================="
    echo "Installing and Configuring Browsers"
    echo "=========================================="
    
    install_firefox
    install_brave
    configure_firefox
    import_bookmarks
    configure_containers
    
    echo "=========================================="
    echo "✓ Browser installation complete"
    echo "=========================================="
    echo ""
    echo "Installed browsers:"
    echo "  - Firefox ESR (primary, hardened)"
    echo "  - Brave (optional, privacy-focused)"
    echo ""
    echo "Firefox features:"
    echo "  - Multi-Account Containers (AWS, Azure, GCP)"
    echo "  - uBlock Origin (pre-installed)"
    echo "  - Hardened privacy settings"
    echo "  - Pre-configured cloud bookmarks"
    echo ""
}

main "$@"
