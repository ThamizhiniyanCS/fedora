#!/bin/bash
# ==============================================================================
# Fedora WSL Initialization Script (DNF5)
# ==============================================================================
# Sets up a fresh Fedora WSL instance with all preferred tools and configuration.
#
# Usage:
#   ./fedora_wsl.sh           # Install everything
#   ./fedora_wsl.sh --info    # Preview what will be installed (dry-run)
#
# Bootstrap on a fresh system (no git required):
#   curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/fedora/main/bootstrap.sh | bash
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV="wsl"

# --- Source shared libraries ---
source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/packages/catalog.sh"

# --- Parse Command-Line Arguments ---
parse_execution_args "$@"

# --- Handle --info flag (dry-run) ---
if [[ "$INFO_MODE" == "true" ]]; then
  print_info "$ENV" "$SCRIPT_DIR"
  exit 0
fi

# ==============================================================================
# Setup
# ==============================================================================
header "Fedora WSL Setup"
keep_sudo_alive

configure_dnf_parallel_downloads

info "Creating temp directory for downloads..."
mkdir -p /tmp/fedora-install-script
cd /tmp/fedora-install-script || exit 1

info "Updating package list..."
sudo dnf check-update || true  # exit code 100 = updates available (not an error)

info "Installing essential prerequisites..."
sudo dnf install -y git gawk  # WSL minimal images may lack these; needed by helpers

# ==============================================================================
# 1. External Repositories (GitHub CLI only — no desktop repos in WSL)
# ==============================================================================
if should_run_step "repos" 1 "External Repositories"; then
  source "$SCRIPT_DIR/modules/repos.sh"
fi

# ==============================================================================
# 2. Script-based installs (rustup, starship, uv, bun, fnm, lazydocker)
# ==============================================================================
if should_run_step "scripts" 2 "Script-based Installs"; then
  install_scripts "$SCRIPT_DIR/packages/scripts.txt"
fi

# ==============================================================================
# 3. COPR packages (lazygit, yazi)
# ==============================================================================
if should_run_step "copr" 3 "COPR Repositories"; then
  install_copr_packages "$SCRIPT_DIR/packages/copr.txt"
fi

# ==============================================================================
# 4. DNF packages (bulk install — WSL-filtered)
# ==============================================================================
if should_run_step "dnf" 4 "DNF Packages"; then
  install_from_manifest "$SCRIPT_DIR/packages/dnf.txt" "$ENV"
fi

# ==============================================================================
# 5. Cargo packages (eza, resvg)
# ==============================================================================
if should_run_step "cargo" 5 "Cargo Packages"; then
  install_cargo_packages "$SCRIPT_DIR/packages/cargo.txt"
fi

# ==============================================================================
# 6. Nerd Fonts (CascadiaCode)
# ==============================================================================
if should_run_step "fonts" 6 "Nerd Fonts"; then
  source "$SCRIPT_DIR/modules/fonts.sh"
fi

# ==============================================================================
# 7. Post-install configuration
# ==============================================================================
if should_run_step "post_install" 7 "Post-install Configuration"; then
  source "$SCRIPT_DIR/modules/post_install.sh"
fi

