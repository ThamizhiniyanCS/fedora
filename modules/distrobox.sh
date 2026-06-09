#!/bin/bash
# ==============================================================================
# Module: Distrobox Container Setup
# ==============================================================================
# Creates distrobox containers from a data-driven manifest, installs packages
# and scripts inside each container, exports apps/binaries to the host, and
# forwards host binaries into containers via distrobox-host-exec symlinks.
#
# Expects:
#   - ENV variable ("bare-metal" or "wsl") to be set by the orchestrator
#   - Helper functions (info, error, success, header) from lib/helpers.sh
#   - SCRIPT_DIR variable from the orchestrator
#   - distrobox and podman to be installed
# ==============================================================================

DISTROBOX_DIR="$SCRIPT_DIR/packages/distrobox"

# ==============================================================================
# Helper: Parse and execute a per-container manifest
# ==============================================================================
# Reads a <container>.txt manifest in two passes:
#   Pass 1 — Collects pkg-manager, packages, scripts, and exports
#   Pass 2 — Executes in order: packages → scripts → export-app → export-bin
#
# Usage: setup_distrobox_container <container_name> <manifest_file>
# ==============================================================================
setup_distrobox_container() {
  local name="$1"
  local manifest="$2"
  local pkg_manager=""
  local section=""
  local current_script_name=""

  local packages=()
  local script_names=()
  local script_cmds=()
  local export_apps=()
  local export_bins=()

  # --- Pass 1: Parse the manifest ---
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Detect section headers
    if [[ "$line" == "[pkg-manager]" ]]; then
      section="pkg-manager"; continue
    elif [[ "$line" == "[packages]" ]]; then
      section="packages"; continue
    elif [[ "$line" =~ ^\[script:(.+)\]$ ]]; then
      section="script"
      current_script_name="${BASH_REMATCH[1]}"
      continue
    elif [[ "$line" == "[export-app]" ]]; then
      section="export-app"; continue
    elif [[ "$line" == "[export-bin]" ]]; then
      section="export-bin"; continue
    fi

    # Collect data based on current section
    case "$section" in
      pkg-manager)
        pkg_manager="$line"
        ;;
      packages)
        packages+=("$(echo "$line" | xargs)")
        ;;
      script)
        script_names+=("$current_script_name")
        script_cmds+=("$line")
        section=""  # Each [script:name] has exactly one command line
        ;;
      export-app)
        export_apps+=("$(echo "$line" | xargs)")
        ;;
      export-bin)
        export_bins+=("$(echo "$line" | xargs)")
        ;;
    esac
  done < "$manifest"

  # --- Pass 2: Execute in order ---

  # 1. Install packages (bulk)
  if [[ ${#packages[@]} -gt 0 && -n "$pkg_manager" ]]; then
    info "Installing packages in container '$name': ${packages[*]}"
    if distrobox enter "$name" -- bash -c "$pkg_manager ${packages[*]}"; then
      success "Packages installed in container '$name'."
    else
      error "Package installation failed in container '$name'."
    fi
  fi

  # 2. Run script-based installers
  for i in "${!script_names[@]}"; do
    info "Running script '${script_names[$i]}' in container '$name'..."
    if distrobox enter "$name" -- bash -c "${script_cmds[$i]}"; then
      success "Script '${script_names[$i]}' completed in container '$name'."
    else
      error "Script '${script_names[$i]}' failed in container '$name'."
    fi
  done

  # 3. Export GUI apps to host
  for app in "${export_apps[@]}"; do
    info "Exporting app '$app' from container '$name' to host..."
    if distrobox enter "$name" -- distrobox-export --app "$app"; then
      success "Exported app '$app' from container '$name'."
    else
      error "Failed to export app '$app' from container '$name'."
    fi
  done

  # 4. Export binaries to host
  for bin in "${export_bins[@]}"; do
    info "Exporting binary '$bin' from container '$name' to host..."
    if distrobox enter "$name" -- distrobox-export --bin "$bin"; then
      success "Exported binary '$bin' from container '$name'."
    else
      error "Failed to export binary '$bin' from container '$name'."
    fi
  done
}

# ==============================================================================
# Helper: Forward host binaries into all containers
# ==============================================================================
# Creates symlinks from /usr/local/bin/<binary> → /usr/bin/distrobox-host-exec
# inside each container. When called by name, distrobox-host-exec transparently
# executes the host's binary.
#
# Usage: forward_host_binaries <host_forward_file>
# ==============================================================================
forward_host_binaries() {
  local file="$1"
  local binaries=()

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    binaries+=("$(echo "$line" | xargs)")
  done < "$file"

  if [[ ${#binaries[@]} -eq 0 ]]; then
    info "No host binaries to forward."
    return 0
  fi

  # Forward into each container listed in containers.txt
  while IFS= read -r container_line; do
    [[ -z "$container_line" || "$container_line" =~ ^[[:space:]]*# ]] && continue
    local container_name
    container_name=$(echo "$container_line" | awk '{print $1}')

    info "Forwarding ${#binaries[@]} host binaries into container '$container_name'..."
    for binary in "${binaries[@]}"; do
      # Only forward if the binary exists on the host
      if command -v "$binary" &>/dev/null; then
        distrobox enter "$container_name" -- \
          sudo ln -sf /usr/bin/distrobox-host-exec "/usr/local/bin/$binary" 2>/dev/null || true
      else
        info "Skipping '$binary' — not found on host."
      fi
    done
    success "Host binaries forwarded into container '$container_name'."
  done < "$DISTROBOX_DIR/containers.txt"
}

# ==============================================================================
# Main: Orchestrate Distrobox setup
# ==============================================================================

# Guard: skip if distrobox is not installed
if ! command -v distrobox &>/dev/null; then
  info "Distrobox is not installed — skipping container setup."
  return 0 2>/dev/null || exit 0
fi

header "Setting up Distrobox containers"

# --- 1. Create containers and run per-container setup ---
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  name=$(echo "$line" | awk '{print $1}')
  image=$(echo "$line" | awk '{print $2}')

  # Idempotent container creation
  if distrobox list 2>/dev/null | grep -q -w "$name"; then
    info "Distrobox container '$name' already exists."
  else
    info "Creating Distrobox container '$name' from image '$image'..."
    if distrobox create --image "$image" --name "$name" -Y; then
      success "Created container '$name'."
    else
      error "Failed to create container '$name'. Skipping its setup."
      continue
    fi
  fi

  # Run per-container manifest if it exists
  local manifest="$DISTROBOX_DIR/${name}.txt"
  if [[ -f "$manifest" ]]; then
    info "Processing manifest for container '$name'..."
    setup_distrobox_container "$name" "$manifest"
  fi

done < "$DISTROBOX_DIR/containers.txt"

# --- 2. Forward host binaries into all containers ---
if [[ -f "$DISTROBOX_DIR/host_forward.txt" ]]; then
  header "Forwarding host binaries into Distrobox containers"
  forward_host_binaries "$DISTROBOX_DIR/host_forward.txt"
fi
