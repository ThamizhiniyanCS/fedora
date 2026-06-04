#!/bin/bash
# ==============================================================================
# Module: External Repository Setup
# ==============================================================================
# Sets up third-party repos and installs their packages.
# Sourced by fedora.sh / fedora_wsl.sh after lib/helpers.sh.
#
# Expects:
#   - ENV variable ("bare-metal" or "wsl") to be set by the orchestrator
#   - Helper functions (install, info, error, success) from lib/helpers.sh
# ==============================================================================

header "Setting up external repositories"

# --- dnf5-plugins (required for dnf config-manager) ---
install dnf5-plugins

# ==============================================================================
# GitHub CLI — all environments
# https://cli.github.com/
# ==============================================================================
info "Adding GitHub CLI repository..."
sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
install gh --repo gh-cli

# ==============================================================================
# VSCodium — bare-metal only
# https://vscodium.com/
# ==============================================================================
if [[ "$ENV" == "bare-metal" ]]; then
  info "Adding VSCodium repository..."
  sudo rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
  printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=download.vscodium.com\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg\nmetadata_expire=1h\n" | sudo tee -a /etc/yum.repos.d/vscodium.repo
  install codium
fi

# ==============================================================================
# DangerZone — bare-metal only
# https://dangerzone.rocks/
# ==============================================================================
if [[ "$ENV" == "bare-metal" ]]; then
  info "Adding DangerZone repository..."
  sudo dnf config-manager addrepo --from-repofile=https://packages.freedom.press/yum-tools-prod/dangerzone/dangerzone.repo
  install dangerzone
fi

# ==============================================================================
# Proton VPN — bare-metal only
# https://protonvpn.com/support/official-linux-vpn-fedora/
# ==============================================================================
if [[ "$ENV" == "bare-metal" ]]; then
  info "Adding Proton VPN repository..."
  local fedora_version
  fedora_version=$(cut -d' ' -f3 /etc/fedora-release)

  wget "https://repo.protonvpn.com/fedora-${fedora_version}-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.3-1.noarch.rpm"
  install ./protonvpn-stable-release-1.0.3-1.noarch.rpm
  sudo dnf check-update --refresh || true

  # System tray icon support
  info "Installing system tray icon support for Proton VPN..."
  install libappindicator-gtk3 gnome-shell-extension-appindicator gnome-extensions-app
fi
