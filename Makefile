# NubiferOS Build System
# Supports two ISO targets: installer-only (production) and live (development)

.PHONY: help iso-installer iso-live clean

# Default target
help:
	@echo "NubiferOS Build Targets:"
	@echo ""
	@echo "  iso-installer  Build production installer-only ISO (recommended)"
	@echo "  iso-live       Build development live ISO (testing only)"
	@echo "  clean          Clean build artifacts"
	@echo ""
	@echo "Production ISO (Alpha/Release):"
	@echo "  make iso-installer"
	@echo ""
	@echo "Development/Testing ISO:"
	@echo "  make iso-live"

# Production installer-only ISO
iso-installer:
	@echo "=========================================="
	@echo "Building Production Installer-Only ISO"
	@echo "=========================================="
	@echo "Target: Production/Alpha release"
	@echo "Features: Installer-only, mandatory encryption"
	@echo "Security: Minimal attack surface"
	@echo ""
	sudo ./build-nubiferos.sh --installer-only

# Development live ISO
iso-live:
	@echo "=========================================="
	@echo "Building Development Live ISO"
	@echo "=========================================="
	@echo "⚠️  WARNING: TESTING ONLY - NOT FOR PRODUCTION"
	@echo "Target: Development, testing, debugging"
	@echo "Features: Live desktop, auto-login"
	@echo "Security: Reduced (live environment)"
	@echo ""
	@read -p "Continue with live ISO build? [y/N] " confirm && [ "$$confirm" = "y" ]
	sudo ./build-nubiferos.sh --live

# Clean build artifacts
clean:
	sudo rm -rf work/ output/ iso/
	@echo "Build artifacts cleaned"