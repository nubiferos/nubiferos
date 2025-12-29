# NubiferOS Build System
# Supports two ISO targets: installer-only (production) and live (development)

.PHONY: help iso-installer iso-live iso-installer-ci iso-live-ci clean

# Default target
help:
	@echo "NubiferOS Build Targets:"
	@echo ""
	@echo "  iso-installer     Build production installer-only ISO (recommended)"
	@echo "  iso-live          Build development live ISO (testing only)"
	@echo "  iso-installer-ci  Build production ISO (non-interactive)"
	@echo "  iso-live-ci       Build development ISO (non-interactive)"
	@echo "  clean             Clean build artifacts"
	@echo ""
	@echo "Production ISO (Alpha/Release):"
	@echo "  make iso-installer"
	@echo ""
	@echo "Development/Testing ISO:"
	@echo "  make iso-live"
	@echo ""
	@echo "CI/Non-Interactive:"
	@echo "  make iso-installer-ci"
	@echo "  make iso-live-ci"
	@echo ""
	@echo "Environment Variables:"
	@echo "  ISO_MODE=installer|live  Set build mode"

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

# CI-friendly targets (non-interactive)
iso-installer-ci:
	@echo "=========================================="
	@echo "Building Production Installer-Only ISO (CI)"
	@echo "=========================================="
	sudo ./build-nubiferos.sh --mode installer --non-interactive

iso-live-ci:
	@echo "=========================================="
	@echo "Building Development Live ISO (CI)"
	@echo "=========================================="
	sudo ./build-nubiferos.sh --mode live --non-interactive

# Clean build artifacts
clean:
	sudo rm -rf work/ output/ iso/
	@echo "Build artifacts cleaned"