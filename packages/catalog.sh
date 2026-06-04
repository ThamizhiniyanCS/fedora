#!/bin/bash
# ==============================================================================
# Package Catalog — Descriptions & URLs
# ==============================================================================
# This file is sourced by the installer scripts.
# It provides human-readable descriptions and links for every tool.
#
# Usage:
#   source packages/catalog.sh
#   echo "${PKG_DESC[ripgrep]}"   # → "Recursively search directories for a regex pattern"
#   echo "${PKG_URL[ripgrep]}"    # → "https://github.com/BurntSushi/ripgrep"
#
# Keys match package names used in the manifest files (dnf.txt, cargo.txt, etc.)
# For sub-packages (e.g. openssl-devel, python3-neovim), only the primary package
# has an entry — the sub-packages are self-explanatory.
# ==============================================================================

declare -A PKG_DESC=(
  # --- git ---
  [git-delta]="A syntax-highlighting pager for git, diff, and grep output"
  [gh]="GitHub's official command line tool"

  # --- openssl ---
  [openssl]="Cryptography and SSL/TLS toolkit"

  # --- editor ---
  [neovim]="Vim-fork focused on extensibility and usability"
  [codium]="Community-driven, freely-licensed binary distribution of VS Code"

  # --- terminal ---
  [kitty]="The fast, feature-rich, GPU based terminal emulator"
  [fish]="Smart and user-friendly command line shell"
  [bat]="A cat(1) clone with syntax highlighting and Git integration"
  [fastfetch]="Feature-rich and performance oriented neofetch-like system info tool"

  # --- cli-tools ---
  [fzf]="A command-line fuzzy finder"
  [lazygit]="Simple terminal UI for git commands"
  [lazydocker]="The lazier way to manage everything docker"
  [ripgrep]="Recursively search directories for a regex pattern"
  [fd-find]="A simple, fast and user-friendly alternative to 'find'"
  [jq]="Command-line JSON processor"
  [zoxide]="A smarter cd command — supports all major shells"
  [xclip]="Command line interface to the X11 clipboard"
  [strace]="Diagnostic, debugging and instructional userspace tracer for Linux"
  [xdotool]="Fake keyboard/mouse input, window management, and more"
  [eza]="A modern alternative to ls"
  [resvg]="An SVG rendering library"
  [yazi]="Blazing fast terminal file manager written in Rust"

  # --- media ---
  [poppler]="PDF rendering library based on the xpdf-3.0 code base"
  [GraphicsMagick]="Swiss army knife of image processing (ImageMagick fork)"
  [vlc]="Free and open source cross-platform multimedia player"
  [flameshot]="Powerful yet simple open-source screenshot software"

  # --- desktop ---
  [gnome-session-xsession]="Adds desktop environment switcher to the login window"
  [open-vm-tools-desktop]="VMware open-vm-tools for desktop integration"
  [dangerzone]="Convert potentially dangerous documents to safe PDFs"
  [protonvpn]="Proton VPN client for Linux"

  # --- system ---
  [btop]="A monitor of system resources"

  # --- flatpak ---
  [md.obsidian.Obsidian]="Private and flexible writing app that adapts to the way you think"
  [app.zen_browser.zen]="Privacy-focused browser based on Firefox with a beautiful UI"
  [io.github.ungoogled_software.ungoogled_chromium]="Chromium with Google services and dependencies removed"

  # --- script-based ---
  [rustup]="Installer for the Rust programming language toolchain"
  [starship]="Minimal, blazing-fast, infinitely customizable shell prompt"
  [uv]="Extremely fast Python package and project manager"
  [bun]="Incredibly fast JavaScript runtime, bundler, and package manager"
  [fnm]="Fast and simple Node.js version manager, built in Rust"
)

declare -A PKG_URL=(
  # --- git ---
  [git-delta]="https://github.com/dandavison/delta"
  [gh]="https://github.com/cli/cli"

  # --- openssl ---
  [openssl]="https://www.openssl.org/"

  # --- editor ---
  [neovim]="https://github.com/neovim/neovim"
  [codium]="https://github.com/VSCodium/vscodium"

  # --- terminal ---
  [kitty]="https://github.com/kovidgoyal/kitty"
  [fish]="https://github.com/fish-shell/fish-shell"
  [bat]="https://github.com/sharkdp/bat"
  [fastfetch]="https://github.com/fastfetch-cli/fastfetch"

  # --- cli-tools ---
  [fzf]="https://github.com/junegunn/fzf"
  [lazygit]="https://github.com/jesseduffield/lazygit"
  [lazydocker]="https://github.com/jesseduffield/lazydocker"
  [ripgrep]="https://github.com/BurntSushi/ripgrep"
  [fd-find]="https://github.com/sharkdp/fd"
  [jq]="https://github.com/jqlang/jq"
  [zoxide]="https://github.com/ajeetdsouza/zoxide"
  [xclip]="https://github.com/astrand/xclip"
  [strace]="https://github.com/strace/strace"
  [xdotool]="https://github.com/jordansissel/xdotool"
  [eza]="https://github.com/eza-community/eza"
  [resvg]="https://github.com/linebender/resvg"
  [yazi]="https://github.com/sxyazi/yazi"

  # --- media ---
  [poppler]="https://gitlab.freedesktop.org/poppler/poppler"
  [GraphicsMagick]="http://www.graphicsmagick.org/"
  [vlc]="https://www.videolan.org/vlc/"
  [flameshot]="https://flameshot.org/"

  # --- desktop ---
  [gnome-session-xsession]=""
  [open-vm-tools-desktop]="https://github.com/vmware/open-vm-tools"
  [dangerzone]="https://github.com/freedomofpress/dangerzone"
  [protonvpn]="https://protonvpn.com/support/official-linux-vpn-fedora/"

  # --- system ---
  [btop]="https://github.com/aristocratos/btop"

  # --- flatpak ---
  [md.obsidian.Obsidian]="https://obsidian.md/"
  [app.zen_browser.zen]="https://zen-browser.app/"
  [io.github.ungoogled_software.ungoogled_chromium]="https://github.com/ungoogled-software/ungoogled-chromium"

  # --- script-based ---
  [rustup]="https://rustup.rs/"
  [starship]="https://github.com/starship/starship"
  [uv]="https://github.com/astral-sh/uv"
  [bun]="https://github.com/oven-sh/bun"
  [fnm]="https://github.com/Schniz/fnm"
)
