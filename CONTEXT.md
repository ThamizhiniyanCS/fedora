# Session Context

> Use this file to resume work in a new session. Paste it or reference it at the start of a new conversation.

## Project

**Repository:** `fedora` — Bash scripts to bootstrap a fresh Fedora (bare-metal and WSL) installation with all preferred tools and configuration.

## What Was Done

Refactored `fedora.sh` and `fedora_wsl.sh` from monolithic scripts into a **data-driven, modular architecture** and subsequently fortified them for robust, non-interactive execution.

### Architecture Structure
```
fedora/
├── bootstrap.sh               # curl one-liner entry point, auto-detects WSL
├── lib/helpers.sh             # Shared functions: logging, keep_sudo_alive, install wrappers, parsers, --info, summary
├── packages/
│   ├── dnf.txt                # DNF packages categorized (dev-tools, tauri, system, etc.) with env tags
│   ├── cargo.txt              # Cargo packages (eza, resvg)
│   ├── copr.txt               # COPR mappings (lazygit, yazi)
│   ├── scripts.txt            # Script-based installers (rustup, starship, burpsuite, etc.)
│   ├── flatpak.txt            # Flatpak packages (Podman Desktop, Obsidian, browsers)
│   └── catalog.sh             # PKG_DESC + PKG_URL associative arrays for all tools
├── modules/
│   ├── repos.sh               # External repo setup (gh, vscodium, dangerzone, protonvpn) - idempotent
│   ├── multimedia.sh          # Codecs, ffmpeg swap, AMD/NVIDIA HW drivers (graceful failures)
│   └── post_install.sh        # Fish shell default, dotfiles git bare repo setup, cleanup, summary
├── fedora.sh                  # Thin orchestrator (ENV=bare-metal)
├── fedora_wsl.sh              # Thin orchestrator (ENV=wsl), skips multimedia
└── CONTEXT.md                 # This file
```

### Key Design Decisions & Improvements
1. **Data-Driven Manifests** — Packages are managed via scannable text files (`dnf.txt`, `flatpak.txt`, etc.) parsed dynamically.
2. **Catalog Metadata** — `catalog.sh` provides queryable documentation (`--info` dry-run mode).
3. **Robust Non-Interactive Execution**:
   - Implemented `keep_sudo_alive` background loop to prevent password timeouts during long installs.
   - Added `--skip-unavailable` to bulk DNF installs and `|| true`/fallbacks for unstable RPM Fusion packages.
   - Forced `-y` on all multimedia/repo commands and used `sudo chsh` to bypass interactive prompts.
   - Added `|| true` to pipechains that use `set -e` to avoid sudden script aborts.
   - Sourced Cargo env dynamically for same-session package installation.
4. **Environment Tagging** — `# bare-metal only` / `# wsl only` inline tags filter packages per environment.
5. **Dotfiles Automation** — Post-install automatically clones and configures a bare git repository for dotfiles, safely overwriting conflicts.

## Current State

The scripts are highly robust, modular, and fully tested against real-world execution hiccups. In the latest session, we:
- Added `org.qbittorrent.qBittorrent` to the Flatpak manifest, `ms-toolsai.jupyter` to VSCodium extensions, and `podman` to the DNF packages.
- Implemented virtualization and nested virtualization setup for bare-metal in `modules/virtualization.sh` (sourced in `fedora.sh`), supporting AMD/Intel CPUs dynamically.
- Built a **data-driven Distrobox integration system** in `modules/distrobox.sh`:
  - `packages/distrobox/containers.txt` — Defines containers (name + image).
  - `packages/distrobox/host_forward.txt` — Host integration binaries (like `flatpak`, `podman`, `systemctl`, `xclip`, `xdg-open`) to symlink into containers via `distrobox-host-exec`.
  - `packages/distrobox/<name>.txt` — Per-container manifests with sections: `[pkg-manager]`, `[packages]`, `[script:name]`, `[export-app]`, `[export-bin]`. Filesystem-sensitive tools (`eza`, `bat`, `rg`, `fd`, `fzf`, `nvim`, `jq`, `zoxide`) and shell prompt helpers (`starship`) are installed natively inside the container here to ensure correct filesystem access.
  - The module creates containers idempotently, installs packages/scripts inside them, exports GUI apps and binaries to the host, and forwards host integration binaries into containers.
  - Initial setup: Ubuntu container with Signal Desktop installed and exported as a GUI app to the host.
- Removed the hardcoded distrobox creation from `post_install.sh` in favor of the new manifest system.
- Implemented **selective step execution and resuming control** in `lib/helpers.sh`:
  - Added support for `--list`, `--from <step>`, `--only <steps>`, and `--exclude <steps>` command-line flags.
  - Wrapped all installation steps in `fedora.sh` (12 steps) and `fedora_wsl.sh` (10 steps) in `should_run_step` conditional blocks.
- Registered all new packages in `catalog.sh`.

