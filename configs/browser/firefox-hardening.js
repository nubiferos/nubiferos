// NubiferOS Firefox Hardening Configuration
// This file is placed in /etc/firefox/syspref.js or user profile prefs.js

// ============================================================================
// Privacy & Security Hardening
// ============================================================================

// Disable telemetry
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);

// Disable Firefox Studies
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);

// Disable Pocket
user_pref("extensions.pocket.enabled", false);

// Enhanced Tracking Protection (Strict)
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);

// Disable WebRTC (can leak real IP)
user_pref("media.peerconnection.enabled", false);

// Disable geolocation
user_pref("geo.enabled", false);

// Disable camera and microphone
user_pref("permissions.default.camera", 2);
user_pref("permissions.default.microphone", 2);

// HTTPS-Only Mode
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// DNS over HTTPS
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");

// Disable prefetching
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);

// Disable link prefetching
user_pref("network.http.speculative-parallel-limit", 0);

// Disable hyperlink auditing
user_pref("browser.send_pings", false);

// ============================================================================
// Security Enhancements
// ============================================================================

// Enable OCSP stapling
user_pref("security.ssl.enable_ocsp_stapling", true);

// Require safe negotiation
user_pref("security.ssl.require_safe_negotiation", true);

// Disable TLS 1.0 and 1.1
user_pref("security.tls.version.min", 3);

// Enable stricter certificate validation
user_pref("security.cert_pinning.enforcement_level", 2);

// Block dangerous and uncommon downloads
user_pref("browser.safebrowsing.downloads.enabled", true);
user_pref("browser.safebrowsing.downloads.remote.block_dangerous", true);
user_pref("browser.safebrowsing.downloads.remote.block_uncommon", true);

// ============================================================================
// Multi-Account Container Configuration
// ============================================================================

// Enable containers
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.ui.enabled", true);

// Pre-configure containers for cloud providers
// AWS Container (Orange)
user_pref("privacy.userContext.extension", "@testpilot-containers");

// ============================================================================
// Performance & UX
// ============================================================================

// Disable animations for performance
user_pref("toolkit.cosmeticAnimations.enabled", false);

// Increase cache size for better performance
user_pref("browser.cache.disk.capacity", 1048576); // 1GB

// Enable hardware acceleration
user_pref("layers.acceleration.force-enabled", true);

// Smooth scrolling
user_pref("general.smoothScroll", true);

// ============================================================================
// Developer Tools
// ============================================================================

// Enable developer tools by default
user_pref("devtools.chrome.enabled", true);
user_pref("devtools.debugger.remote-enabled", true);

// ============================================================================
// NubiferOS Specific
// ============================================================================

// Set homepage to NubiferOS dashboard (when implemented)
user_pref("browser.startup.homepage", "about:blank");

// New tab page
user_pref("browser.newtabpage.enabled", true);

// Disable sponsored content
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);

// ============================================================================
// Cookie & Storage Settings
// ============================================================================

// Delete cookies and site data when Firefox closes (except for containers)
user_pref("privacy.sanitize.sanitizeOnShutdown", false); // Don't auto-delete
user_pref("privacy.clearOnShutdown.cookies", false);
user_pref("privacy.clearOnShutdown.cache", true); // Clear cache only

// First-party isolation (enhanced privacy)
user_pref("privacy.firstparty.isolate", true);

// Resist fingerprinting
user_pref("privacy.resistFingerprinting", true);

// ============================================================================
// Extension Recommendations
// ============================================================================

// These extensions should be pre-installed or recommended:
// - Firefox Multi-Account Containers (built-in)
// - uBlock Origin (ad/tracker blocking)
// - HTTPS Everywhere (force HTTPS)
// - Privacy Badger (tracker blocking)
// - Bitwarden (password manager - integrates with Credential Manager)

// ============================================================================
// Cloud Provider Specific Settings
// ============================================================================

// Allow popups for cloud consoles (they use them extensively)
// These will be set per-container
// user_pref("dom.disable_open_during_load", false); // Only for specific sites

// ============================================================================
// Workspace Integration
// ============================================================================

// Custom CSS for container tab colors matching NubiferOS workspace colors
// AWS: #FF9900 (Orange)
// Azure: #0078D4 (Blue)
// GCP: #EA4335 (Red)
// This will be handled by userChrome.css

// ============================================================================
// Security Warnings
// ============================================================================

// Show warning for insecure password fields
user_pref("security.insecure_field_warning.contextual.enabled", true);

// Warn when entering insecure sites
user_pref("security.insecure_connection_text.enabled", true);

// ============================================================================
// Auto-updates
// ============================================================================

// Enable automatic updates for Firefox
user_pref("app.update.auto", true);

// Enable automatic updates for extensions
user_pref("extensions.update.enabled", true);
user_pref("extensions.update.autoUpdateDefault", true);
