# Session Context

> Use this file to resume work in a new session. Paste it or reference it at the start of a new conversation.

## Project

**Repository:** `os-init-scripts` — Bash scripts to bootstrap a fresh Fedora (bare-metal and WSL) installation with all preferred tools and configuration.

## What Was Done

Refactored `fedora.sh` and `fedora_wsl.sh` from monolithic scripts into a **data-driven, modular architecture** and subsequently fortified them for robust, non-interactive execution.

### Architecture Structure
```
os-init-scripts/
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
- Added `gnome-tweaks` to DNF packages (bare-metal only) and enabled `btop` to be installed in both environments.
- Added `org.gnome.Extensions`, `io.ente.auth`, and `org.telegram.desktop` Flatpak app IDs.
- Added `tree-sitter-cli`, `tectonic` (with conditional directory check), and `mmdc` script installers.
- Integrated `rust-analyzer` component install directly into the `rustup` installer script command.
- Optimized `burpsuite` installation to show download progress by removing `-q` from `wget`.
- Configured `starship` installer to run unattended/non-interactively with `-y`.
- Moved interactive installers (e.g. `burpsuite`) to a separate `interactive_scripts.txt` manifest run at the very end of the installation process (after dotfiles configuration).
- Documented all new tools and packages in the `catalog.sh` registry.

