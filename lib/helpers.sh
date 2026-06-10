#!/bin/bash
# ==============================================================================
# Shared helper functions for fedora
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
# Sudo Keep-Alive
# ==============================================================================

# Ask for the administrator password upfront and keep the timestamp alive
keep_sudo_alive() {
  info "Prompting for sudo password (will be kept alive until script finishes)..."
  sudo -v
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

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

  # Interactive script-based installs
  if [[ -f "$script_dir/packages/interactive_scripts.txt" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        local name="${BASH_REMATCH[1]}"
        local desc="${PKG_DESC[$name]:-}"
        printf "  %-25s %-10s %s\n" "$name" "script (int)" "$desc"
      fi
    done < "$script_dir/packages/interactive_scripts.txt"
  fi


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

# ==============================================================================
# Execution Control (Selective Step Execution)
# ==============================================================================

START_STEP=""
ONLY_STEPS=""
EXCLUDE_STEPS=""
HAS_REACHED_START=false
INFO_MODE=false

list_steps() {
  header "Available Steps for Environment: $ENV"
  if [[ "$ENV" == "bare-metal" ]]; then
    echo "  1. repos          - External Repositories"
    echo "  2. scripts        - Script-based Installs"
    echo "  3. copr           - COPR Repositories"
    echo "  4. dnf            - DNF Packages"
    echo "  5. cargo          - Cargo Packages"
    echo "  6. flatpak        - Flatpak Packages"
    echo "  7. multimedia     - Multimedia & Codecs"
    echo "  8. virtualization - Virtualization & Nested Virtualization"
    echo "  9. vscodium       - VSCodium Extensions"
    echo "  10. fonts         - Nerd Fonts"
    echo "  11. distrobox     - Distrobox Containers"
    echo "  12. post_install  - Post-install Configuration"
  else
    echo "  1. repos          - External Repositories"
    echo "  2. scripts        - Script-based Installs"
    echo "  3. copr           - COPR Repositories"
    echo "  4. dnf            - DNF Packages"
    echo "  5. cargo          - Cargo Packages"
    echo "  6. flatpak        - Flatpak Packages"
    echo "  7. multimedia     - Multimedia & Codecs (skipped)"
    echo "  8. fonts          - Nerd Fonts"
    echo "  9. distrobox      - Distrobox Containers"
    echo "  10. post_install  - Post-install Configuration"
  fi
  echo ""
}

show_help() {
  echo "Usage: $(basename "$0") [options]"
  echo ""
  echo "Options:"
  echo "  --info            Preview what will be installed (dry-run)"
  echo "  --from <step>     Start execution from the specified step name or number"
  echo "  --only <steps>    Comma-separated list of step names/numbers to execute"
  echo "  --exclude <steps> Comma-separated list of step names/numbers to skip"
  echo "  --list            List all available steps for this environment and exit"
  echo "  -h, --help        Show this help message and exit"
  echo ""
  list_steps
}

parse_execution_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)
        if [[ -z "${2:-}" ]]; then
          error "--from option requires a step name or number."
          exit 1
        fi
        START_STEP="$2"
        shift 2
        ;;
      --only)
        if [[ -z "${2:-}" ]]; then
          error "--only option requires a comma-separated list of steps."
          exit 1
        fi
        ONLY_STEPS=",$2,"
        shift 2
        ;;
      --exclude)
        if [[ -z "${2:-}" ]]; then
          error "--exclude option requires a comma-separated list of steps."
          exit 1
        fi
        EXCLUDE_STEPS=",$2,"
        shift 2
        ;;
      --list)
        list_steps
        exit 0
        ;;
      --info)
        INFO_MODE=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        error "Unknown argument: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

should_run_step() {
  local step_id="$1"
  local step_num="$2"
  local step_desc="$3"

  # 1. Check if step is explicitly excluded
  if [[ -n "$EXCLUDE_STEPS" ]]; then
    if [[ "$EXCLUDE_STEPS" == *",$step_id,"* || "$EXCLUDE_STEPS" == *",$step_num,"* ]]; then
      info "Skipping step $step_num ($step_id): $step_desc (Excluded)"
      return 1
    fi
  fi

  # 2. Check if we are running ONLY specific steps
  if [[ -n "$ONLY_STEPS" ]]; then
    if [[ "$ONLY_STEPS" == *",$step_id,"* || "$ONLY_STEPS" == *",$step_num,"* ]]; then
      info "Executing step $step_num ($step_id): $step_desc..."
      return 0
    else
      return 1
    fi
  fi

  # 3. Check if we are starting from a specific step
  if [[ -n "$START_STEP" ]]; then
    if [[ "$HAS_REACHED_START" == "true" ]]; then
      info "Executing step $step_num ($step_id): $step_desc..."
      return 0
    fi

    # Check if this step matches starting step (by ID or number)
    if [[ "$START_STEP" == "$step_id" || "$START_STEP" == "$step_num" ]]; then
      HAS_REACHED_START=true
      info "Starting execution from step $step_num ($step_id): $step_desc..."
      return 0
    else
      info "Skipping step $step_num ($step_id): $step_desc (Starts later)"
      return 1
    fi
  fi

  # Default: run the step
  info "Executing step $step_num ($step_id): $step_desc..."
  return 0
}

# ==============================================================================
# DNF Configuration Optimization
# ==============================================================================
configure_dnf_parallel_downloads() {
  info "Optimizing DNF parallel downloads..."

  # Try the native DNF command first
  if sudo dnf config-manager setopt max_parallel_downloads=10 &>/dev/null; then
    success "DNF parallel downloads optimized (max_parallel_downloads=10)."
  else
    # Fallback to direct file modification if config-manager is not supported/available
    local config_updated=false
    for config_file in "/etc/dnf/dnf.conf" "/etc/dnf/dnf5.conf"; do
      if [[ -f "$config_file" ]]; then
        # 1. If [main] header is missing, prepend it to prevent DNF config errors
        if ! grep -q "^\[main\]" "$config_file" 2>/dev/null; then
          local temp_content=""
          if grep -q "max_parallel_downloads" "$config_file" 2>/dev/null; then
            temp_content=$(cat "$config_file")
            echo -e "[main]\n$temp_content" | sudo tee "$config_file" > /dev/null
          else
            echo -e "[main]\ngpgcheck=1\ninstallonly_limit=3\nclean_requirements_on_remove=True\nbest=False\nskip_if_unavailable=True" | sudo tee "$config_file" > /dev/null
          fi
        fi

        # 2. Add or update parallel downloads optimization
        if ! grep -q "^max_parallel_downloads" "$config_file" 2>/dev/null; then
          echo "max_parallel_downloads=10" | sudo tee -a "$config_file" > /dev/null
        else
          sudo sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=10/' "$config_file"
        fi
        config_updated=true
      fi
    done

    if [[ "$config_updated" == "true" ]]; then
      success "DNF parallel downloads optimized (max_parallel_downloads=10) via fallback."
    else
      info "No DNF config files found to optimize."
    fi
  fi
}


