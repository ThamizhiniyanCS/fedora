# os-init-scripts

Bash scripts to bootstrap a fresh **Fedora** installation (bare-metal or WSL) with all preferred tools, codecs, and configuration.

## Quick Start

**On a fresh Fedora system** (no git required):

```bash
curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/os-init-scripts/main/bootstrap.sh | bash
```

This auto-detects WSL vs bare-metal and runs the appropriate script.

**If you already have the repo cloned:**

```bash
# Bare-metal
./fedora.sh

# WSL
./fedora_wsl.sh

# Preview what will be installed (dry-run)
./fedora.sh --info
```

## What Gets Installed

Run `./fedora.sh --info` for a full table. Here's the overview:

| Category | Packages |
|---|---|
| **Git** | git-delta, gh (GitHub CLI) |
| **Editor** | neovim, VSCodium |
| **Terminal** | kitty¹, fish, bat, fastfetch |
| **CLI Tools** | fzf, ripgrep, fd, jq, zoxide, xclip, strace, xdotool¹, eza, yazi, lazygit, lazydocker |
| **Media** | poppler, GraphicsMagick, VLC¹, flameshot¹ |
| **Desktop** | open-vm-tools¹, dangerzone¹, Proton VPN¹ |
| **Runtimes** | rustup, uv (Python), bun (JS), fnm (Node.js) |
| **Shell** | fish (set as default), starship (prompt) |
| **Multimedia** | Full ffmpeg, AMD/NVIDIA HW codecs¹ |
| **Flatpak Apps** | Obsidian, Zen Browser, Ungoogled Chromium |
| **VSCodium Ext.** | 22 extensions (Python, Rust, web dev, linting, etc.) |
| **System** | btop² |

> ¹ bare-metal only &nbsp;&nbsp; ² WSL only

## Project Structure

```
os-init-scripts/
├── bootstrap.sh               # curl one-liner entry point
├── fedora.sh                  # Orchestrator — bare-metal
├── fedora_wsl.sh              # Orchestrator — WSL
├── lib/
│   └── helpers.sh             # Shared functions (install, parsers, logging)
├── packages/
│   ├── dnf.txt                # DNF packages — categorized, env-tagged
│   ├── cargo.txt              # Cargo packages
│   ├── copr.txt               # COPR repo → package mappings
│   ├── flatpak.txt            # Flatpak app IDs from Flathub
│   ├── vscodium_extensions.txt # VSCodium extension IDs
│   ├── scripts.txt            # curl-based installers
│   └── catalog.sh             # Descriptions & URLs for every tool
├── modules/
│   ├── repos.sh               # External repository setup
│   ├── multimedia.sh          # Codec & driver setup (bare-metal only)
│   └── post_install.sh        # Shell config, cleanup, summary
├── parrot_os.sh               # Parrot OS setup (standalone)
└── windows.ps1                # Windows setup (standalone)
```

## How to Add a New Package

### DNF package

Add one line to `packages/dnf.txt` under the appropriate category:

```ini
[cli-tools]
my-new-tool                      # bare-metal only  ← optional env tag
```

Then add documentation to `packages/catalog.sh`:

```bash
[my-new-tool]="Description of what it does"   # in PKG_DESC
[my-new-tool]="https://github.com/..."        # in PKG_URL
```

### Cargo package

Add to `packages/cargo.txt`:

```
my-cargo-tool
```

### Flatpak app

Add to `packages/flatpak.txt`:

```
com.example.MyApp
```

### VSCodium extension

Add to `packages/vscodium_extensions.txt`:

```
publisher.extension-name
```

### COPR package

Add to `packages/copr.txt`:

```
owner/repo-name    package-name
```

### Script-based install (curl | sh)

Add to `packages/scripts.txt`:

```ini
[tool-name]
curl -sSf https://example.com/install.sh | sh
```

## How It Works

```
fedora.sh / fedora_wsl.sh
  │
  ├── 1. Source lib/helpers.sh + packages/catalog.sh
  ├── 2. Create temp dir, dnf check-update
  ├── 3. modules/repos.sh        → external repo setup
  ├── 4. packages/scripts.txt    → curl-based installs
  ├── 5. packages/copr.txt       → COPR repos + packages
  ├── 6. packages/dnf.txt        → bulk dnf install (filtered by env)
  ├── 7. packages/cargo.txt      → cargo install
  ├── 8. packages/flatpak.txt    → flatpak install from Flathub
  ├── 9. vscodium_extensions.txt → codium --install-extension (bare-metal only)
  ├── 10. modules/multimedia.sh  → codecs & drivers (bare-metal only)
  ├── 11. modules/post_install.sh → shell config, cleanup
  └── 12. Print summary (successes + failures)
```

The only difference between `fedora.sh` and `fedora_wsl.sh` is the `ENV` variable (`bare-metal` vs `wsl`), which filters packages tagged with `# bare-metal only` or `# wsl only` in the manifest files.

## Environment Tags

Packages in `packages/dnf.txt` can be tagged for a specific environment:

```ini
kitty                    # bare-metal only   ← skipped on WSL
btop                     # wsl only          ← skipped on bare-metal
ripgrep                  # no tag = installed everywhere
```

## Requirements

- Fedora (with DNF5)
- `curl` (pre-installed on Fedora)
- `sudo` access
