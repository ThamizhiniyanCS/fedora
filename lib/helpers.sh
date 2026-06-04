#!/bin/bash
# ==============================================================================
# Shared helper functions for os-init-scripts
# Sourced by fedora.sh and fedora_wsl.sh
# ==============================================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Tracking arrays ---
FAILED_PACKAGES=()
SUCCEEDED_PACKAGES=()

# ==============================================================================
# Logging
# ==============================================================================

info()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
header()  { echo -e "\n${BLUE}${BOLD}=== $1 ===${NC}\n"; }

# ==============================================================================
# Package Installation
# ==============================================================================

# Install one or more packages via dnf
install() {
  if [[ $# -eq 0 ]]; then
    error "No package names provided."
    return 1
  fi

  info "Installing: $*"
  if sudo dnf install -y --skip-unavailable "$@"; then
    success "Successfully installed: $*"
    SUCCEEDED_PACKAGES+=("$*")
  else
    error "Failed to install: $*"
    FAILED_PACKAGES+=("$*")
    return 1
  fi
}

# Enable a COPR repository
copr_enable() {
  if [[ $# -eq 0 ]]; then
    error "No COPR repo provided."
    return 1
  fi

  info "Enabling COPR: $1"
  if sudo dnf copr enable -y "$1"; then
    success "Successfully enabled COPR: $1"
  else
    error "Failed to enable COPR: $1"
    FAILED_PACKAGES+=("copr:$1")
    return 1
  fi
}

# ==============================================================================
# Manifest Parsing
# ==============================================================================

# Parse a package manifest file, filtering by environment.
# Skips comments (#), blank lines, and [category] headers.
# Filters out packages tagged for the other environment.
#
# Usage: parse_packages <file> <environment>
# Arguments:
#   file        - Path to the manifest file
#   environment - "bare-metal" or "wsl"
# Output: Package names, one per line (stdout)
parse_packages() {
  local file="$1"
  local env="$2"
  local skip_tag=""

  if [[ "$env" == "bare-metal" ]]; then
    skip_tag="wsl only"
  elif [[ "$env" == "wsl" ]]; then
    skip_tag="bare-metal only"
  fi

  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    # Skip comment lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    # Skip category headers
    [[ "$line" =~ ^\[.*\]$ ]] && continue

    # Skip packages tagged for the other environment
    if [[ -n "$skip_tag" && "$line" == *"# $skip_tag"* ]]; then
      continue
    fi

    # Extract package name (strip inline comments and surrounding whitespace)
    echo "${line%%#*}" | xargs
  done < "$file"
}

# Install all packages from a DNF manifest file (bulk install)
#
# Usage: install_from_manifest <file> <environment>
install_from_manifest() {
  local file="$1"
  local env="$2"

  header "Installing DNF packages"

  local pkg_array=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && pkg_array+=("$pkg")
  done <<< "$(parse_packages "$file" "$env")"

  if [[ ${#pkg_array[@]} -gt 0 ]]; then
    install "${pkg_array[@]}"
  else
    info "No DNF packages to install."
  fi
}

# Enable COPR repos and install their packages from a manifest file.
# File format: <copr_repo>  <package_name>   (whitespace-separated, one per line)
#
# Usage: install_copr_packages <file>
install_copr_packages() {
  local file="$1"

  header "Installing COPR packages"

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local repo pkg
    repo=$(echo "$line" | awk '{print $1}')
    pkg=$(echo "$line" | awk '{print $2}')

    copr_enable "$repo"
    install "$pkg"
  done < "$file"
}

# Install packages via cargo from a manifest file.
# File format: same as dnf.txt (package names with optional [category] headers)
#
# Usage: install_cargo_packages <file>
install_cargo_packages() {
  local file="$1"

  header "Installing Cargo packages"

  # Source cargo environment if not in PATH (needed for same-session installs)
  if ! command -v cargo &> /dev/null && [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
  fi

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^\[.*\]$ ]] && continue

    local pkg
    pkg=$(echo "$line" | xargs)

    info "Installing $pkg via cargo..."
    if cargo install "$pkg"; then
      success "Successfully installed (cargo): $pkg"
      SUCCEEDED_PACKAGES+=("cargo:$pkg")
    else
      error "Failed to install (cargo): $pkg"
      FAILED_PACKAGES+=("cargo:$pkg")
    fi
  done < "$file"
}

# Run script-based installers from a manifest file.
# File format:
#   [tool_name]
#   <shell command to run>
#
# Usage: install_scripts <file>
install_scripts() {
  local file="$1"
  local name=""

  header "Installing script-based packages"

  while IFS= read -r line; do
    # Skip empty and comment lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # [name] header sets the current tool name
    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      name="${BASH_REMATCH[1]}"
      continue
    fi

    # Non-header line is the install command
    if [[ -n "$name" ]]; then
      info "Installing $name via script..."
      if eval "$line"; then
        success "Successfully installed (script): $name"
        SUCCEEDED_PACKAGES+=("script:$name")
      else
        error "Failed to install (script): $name"
        FAILED_PACKAGES+=("script:$name")
      fi
      name=""
    fi
  done < "$file"
}

# Install Flatpak packages from a manifest file.
# Ensures Flathub remote is added, then installs each app ID.
# File format: same as dnf.txt (app IDs with optional [category] headers)
#
# Usage: install_flatpak_packages <file>
install_flatpak_packages() {
  local file="$1"

  header "Installing Flatpak packages"

  # Ensure Flathub remote is available
  if ! flatpak remotes | grep -q flathub; then
    info "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^\[.*\]$ ]] && continue

    local app_id
    app_id=$(echo "$line" | xargs)

    info "Installing $app_id via Flatpak..."
    if flatpak install -y flathub "$app_id"; then
      success "Successfully installed (flatpak): $app_id"
      SUCCEEDED_PACKAGES+=("flatpak:$app_id")
    else
      error "Failed to install (flatpak): $app_id"
      FAILED_PACKAGES+=("flatpak:$app_id")
    fi
  done < "$file"
}

# Install VSCodium extensions from a manifest file.
# Skips if `codium` is not installed (e.g. on WSL).
# File format: same as dnf.txt (extension IDs with optional [category] headers)
#
# Usage: install_vscodium_extensions <file>
install_vscodium_extensions() {
  local file="$1"

  if ! command -v codium &>/dev/null; then
    info "VSCodium not found — skipping extension installs."
    return 0
  fi

  header "Installing VSCodium extensions"

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^\[.*\]$ ]] && continue

    local ext_id
    ext_id=$(echo "$line" | xargs)

    info "Installing extension: $ext_id"
    if codium --install-extension "$ext_id" --force; then
      success "Successfully installed extension: $ext_id"
      SUCCEEDED_PACKAGES+=("ext:$ext_id")
    else
      error "Failed to install extension: $ext_id"
      FAILED_PACKAGES+=("ext:$ext_id")
    fi
  done < "$file"
}

# ==============================================================================
# Info / Dry-run
# ==============================================================================

# Print a formatted table of all packages that will be installed.
# Requires packages/catalog.sh to be sourced first.
#
# Usage: print_info <environment> <script_dir>
print_info() {
  local env="$1"
  local script_dir="$2"

  header "Packages to be installed (environment: $env)"

  printf "  ${BOLD}%-25s %-10s %s${NC}\n" "Package" "Source" "Description"
  printf "  %-25s %-10s %s\n" "─────────────────────────" "──────────" "─────────────────────────────────────────"

  # DNF packages
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local desc="${PKG_DESC[$pkg]:-}"
    printf "  %-25s %-10s %s\n" "$pkg" "dnf" "$desc"
  done <<< "$(parse_packages "$script_dir/packages/dnf.txt" "$env")"

  # COPR packages
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    local pkg
    pkg=$(echo "$line" | awk '{print $2}')
    local desc="${PKG_DESC[$pkg]:-}"
    printf "  %-25s %-10s %s\n" "$pkg" "copr" "$desc"
  done < "$script_dir/packages/copr.txt"

  # Cargo packages
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^\[.*\]$ ]] && continue
    local pkg
    pkg=$(echo "$line" | xargs)
    local desc="${PKG_DESC[$pkg]:-}"
    printf "  %-25s %-10s %s\n" "$pkg" "cargo" "$desc"
  done < "$script_dir/packages/cargo.txt"

  # Script-based installs
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local desc="${PKG_DESC[$name]:-}"
      printf "  %-25s %-10s %s\n" "$name" "script" "$desc"
    fi
  done < "$script_dir/packages/scripts.txt"

  # Flatpak packages
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^\[.*\]$ ]] && continue
    local app_id
    app_id=$(echo "$line" | xargs)
    local desc="${PKG_DESC[$app_id]:-}"
    printf "  %-25s %-10s %s\n" "$app_id" "flatpak" "$desc"
  done < "$script_dir/packages/flatpak.txt"

  # Repo-managed packages (from catalog entries marked as repo-installed)
  # These are handled by modules/repos.sh
  echo ""
  info "Additional packages installed via external repos (see modules/repos.sh):"
  for pkg in gh codium dangerzone protonvpn; do
    local desc="${PKG_DESC[$pkg]:-}"
    printf "  %-25s %-10s %s\n" "$pkg" "repo" "$desc"
  done

  # VSCodium extensions (bare-metal only)
  if [[ "$env" == "bare-metal" ]]; then
    echo ""
    info "VSCodium extensions (see packages/vscodium_extensions.txt):"
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ ^\[.*\]$ ]] && continue
      local ext_id
      ext_id=$(echo "$line" | xargs)
      printf "  %-25s %-10s\n" "$ext_id" "extension"
    done < "$script_dir/packages/vscodium_extensions.txt"
  fi

  echo ""
}

# ==============================================================================
# Summary
# ==============================================================================

# Print a summary of all installation results
print_summary() {
  header "Installation Summary"

  if [[ ${#SUCCEEDED_PACKAGES[@]} -gt 0 ]]; then
    success "Successfully installed (${#SUCCEEDED_PACKAGES[@]}):"
    printf '  %s\n' "${SUCCEEDED_PACKAGES[@]}"
  fi

  echo ""

  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    error "Failed to install (${#FAILED_PACKAGES[@]}):"
    printf '  %s\n' "${FAILED_PACKAGES[@]}"
    echo ""
    error "Review the failures above and retry manually if needed."
    return 1
  else
    success "All packages installed successfully!"
  fi
}
