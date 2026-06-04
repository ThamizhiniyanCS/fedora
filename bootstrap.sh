#!/bin/bash
# ==============================================================================
# Bootstrap — run this on a fresh Fedora system to fetch and execute the setup
# ==============================================================================
#
# Usage (one-liner on a fresh system):
#   curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/os-init-scripts/main/bootstrap.sh | bash
#
# What it does:
#   1. Downloads the repo as a tarball (no git required)
#   2. Extracts it to /tmp
#   3. Runs fedora.sh (or fedora_wsl.sh if running inside WSL)
# ==============================================================================

set -euo pipefail

REPO="ThamizhiniyanCS/os-init-scripts"
BRANCH="main"
DOWNLOAD_DIR="/tmp"
DIR_NAME="os-init-scripts-${BRANCH}"

echo "[!] Downloading os-init-scripts..."
curl -sL "https://github.com/${REPO}/archive/${BRANCH}.tar.gz" | tar xz -C "$DOWNLOAD_DIR"

cd "${DOWNLOAD_DIR}/${DIR_NAME}"

# Detect if running inside WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "[!] WSL detected — running fedora_wsl.sh"
  chmod +x fedora_wsl.sh
  ./fedora_wsl.sh
else
  echo "[!] Bare-metal detected — running fedora.sh"
  chmod +x fedora.sh
  ./fedora.sh
fi
