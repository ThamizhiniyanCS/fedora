#!/bin/bash
# ==============================================================================
# Fedora Bare-Metal Initialization Script (DNF5)
# ==============================================================================
# Sets up a fresh Fedora workstation with all preferred tools and configuration.
#
# Usage:
#   ./fedora.sh           # Install everything
#   ./fedora.sh --info    # Preview what will be installed (dry-run)
#
# Bootstrap on a fresh system (no git required):
#   curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/os-init-scripts/main/bootstrap.sh | bash
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV="bare-metal"

# --- Source shared libraries ---
source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/packages/catalog.sh"

# --- Handle --info flag (dry-run) ---
if [[ "${1:-}" == "--info" ]]; then
  print_info "$ENV" "$SCRIPT_DIR"
  exit 0
fi

# ==============================================================================
# Setup
# ==============================================================================
header "Fedora Bare-Metal Setup"

info "Creating temp directory for downloads..."
mkdir -p /tmp/fedora-install-script
cd /tmp/fedora-install-script || exit 1

info "Updating package list..."
sudo dnf check-update || true  # exit code 100 = updates available (not an error)

# ==============================================================================
# 1. External Repositories (GitHub CLI, VSCodium, DangerZone, Proton VPN)
# ==============================================================================
source "$SCRIPT_DIR/modules/repos.sh"

# ==============================================================================
# 2. Script-based installs (rustup, starship, uv, bun, fnm, lazydocker)
# ==============================================================================
install_scripts "$SCRIPT_DIR/packages/scripts.txt"

# ==============================================================================
# 3. COPR packages (lazygit, yazi)
# ==============================================================================
install_copr_packages "$SCRIPT_DIR/packages/copr.txt"

# ==============================================================================
# 4. DNF packages (bulk install)
# ==============================================================================
install_from_manifest "$SCRIPT_DIR/packages/dnf.txt" "$ENV"

# ==============================================================================
# 5. Cargo packages (eza, resvg)
# ==============================================================================
install_cargo_packages "$SCRIPT_DIR/packages/cargo.txt"

# ==============================================================================
# 6. Flatpak packages (Obsidian, Zen Browser, Ungoogled Chromium)
# ==============================================================================
install_flatpak_packages "$SCRIPT_DIR/packages/flatpak.txt"

# ==============================================================================
# 7. Multimedia & codecs
# ==============================================================================
source "$SCRIPT_DIR/modules/multimedia.sh"

# ==============================================================================
# 8. VSCodium extensions (bare-metal only)
# ==============================================================================
install_vscodium_extensions "$SCRIPT_DIR/packages/vscodium_extensions.txt"

# ==============================================================================
# 9. Nerd Fonts (CascadiaCode)
# ==============================================================================
source "$SCRIPT_DIR/modules/fonts.sh"

# ==============================================================================
# 10. Post-install configuration
# ==============================================================================
source "$SCRIPT_DIR/modules/post_install.sh"
