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

# Import bookmarks
import_bookmarks() {
    echo "Preparing bookmark import..."
    
    # Copy bookmarks to shared location
    mkdir -p /usr/share/nubifer/browser
    cp "${SCRIPT_DIR}/firefox-bookmarks.json" /usr/share/nubifer/browser/
    
    # Create import script for first-run
    cat > /usr/share/nubifer/browser/import-bookmarks.sh << 'EOF'
#!/bin/bash
# Import NubiferOS bookmarks on first run

FIREFOX_PROFILE=$(find ~/.mozilla/firefox -name "*.default-esr" | head -n1)

if [ -n "$FIREFOX_PROFILE" ]; then
    # Import bookmarks using Firefox's bookmark backup format
    # This will be done via the Resource Viewer UI or manual import
    echo "Firefox profile found: $FIREFOX_PROFILE"
    echo "Import bookmarks from: /usr/share/nubifer/browser/firefox-bookmarks.json"
fi
EOF
    
    chmod +x /usr/share/nubifer/browser/import-bookmarks.sh
    
    echo "✓ Bookmarks prepared for import"
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
