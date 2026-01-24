# NubiferOS Build System

.PHONY: help iso iso-ci clean

# Default target
help:
	@echo "NubiferOS Build Targets:"
	@echo ""
	@echo "  iso       Build NubiferOS ISO (interactive)"
	@echo "  iso-ci    Build NubiferOS ISO (non-interactive, for CI)"
	@echo "  clean     Clean build artifacts"
	@echo ""
	@echo "Build ISO:"
	@echo "  make iso"
	@echo ""
	@echo "CI/Automated Build:"
	@echo "  make iso-ci"
	@echo ""
	@echo "Notes:"
	@echo "  NubiferOS only builds installer-only ISOs for security."
	@echo "  The live CD functionality has been removed."

# Build NubiferOS ISO
iso:
	@echo "=========================================="
	@echo "Building NubiferOS Installer ISO"
	@echo "=========================================="
	@echo "Type: Installer-only (production)"
	@echo "Security: LUKS encryption, minimal attack surface"
	@echo ""
	sudo ./build-nubiferos.sh

# CI-friendly target (non-interactive)
iso-ci:
	@echo "=========================================="
	@echo "Building NubiferOS ISO (CI Mode)"
	@echo "=========================================="
	sudo ./build-nubiferos.sh --non-interactive

# Clean build artifacts
clean:
	sudo rm -rf work/ output/ iso/
	@echo "Build artifacts cleaned"
