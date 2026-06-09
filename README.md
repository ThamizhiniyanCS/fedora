# fedora

Bash scripts to bootstrap a fresh **Fedora** installation (bare-metal or WSL) with all preferred tools, codecs, and configuration.

## Quick Start

**On a fresh Fedora system** (no git required):

```bash
curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/fedora/main/bootstrap.sh | bash

# To pass selective execution arguments (e.g. only distrobox):
curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/fedora/main/bootstrap.sh | bash -s -- --only distrobox
```

This auto-detects WSL vs bare-metal, passes the arguments through, and runs the appropriate script.


**If you already have the repo cloned:**

```bash
# Bare-metal
./fedora.sh

# WSL
./fedora_wsl.sh

# Preview what will be installed (dry-run)
./fedora.sh --info

# List available steps for selective execution
./fedora.sh --list

# Start/resume execution from a specific step (e.g., distrobox onwards)
./fedora.sh --from distrobox

# Run ONLY specific steps (comma-separated list of step IDs or numbers)
./fedora.sh --only virtualization,distrobox

# Exclude specific steps
./fedora.sh --exclude fonts
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
| **Desktop** | open-vm-tools¹, dangerzone¹, Proton VPN¹, Burp Suite |
| **Runtimes** | rustup, uv (Python), bun (JS), fnm (Node.js) |
| **Shell** | fish (set as default), starship (prompt) |
| **Multimedia** | Full ffmpeg, AMD/NVIDIA HW codecs¹ |
| **Flatpak Apps** | Obsidian, Zen Browser, Ungoogled Chromium, Podman Desktop |
| **Dev Tools** | C-development group, Tauri prerequisites, dbus-devel, pkgconf |
| **VSCodium Ext.** | 22 extensions (Python, Rust, web dev, linting, etc.) |
| **System** | btop² |

> ¹ bare-metal only &nbsp;&nbsp; ² WSL only

## Project Structure

```
fedora/
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
  ├── 2. Parse arguments and check dry-run (--info)
  ├── 3. Create temp dir, dnf check-update
  ├── 4. Step 1: modules/repos.sh        → external repo setup
  ├── 5. Step 2: packages/scripts.txt    → curl-based installs
  ├── 6. Step 3: packages/copr.txt       → COPR repos + packages
  ├── 7. Step 4: packages/dnf.txt        → bulk dnf install (filtered by env)
  ├── 8. Step 5: packages/cargo.txt      → cargo install
  ├── 9. Step 6: packages/flatpak.txt    → flatpak install from Flathub
  ├── 10. Step 7: modules/multimedia.sh  → codecs & drivers (bare-metal only)
  ├── 11. Step 8: modules/virtualization.sh → nested virtualization (bare-metal only)
  ├── 12. Step 9: packages/vscodium_extensions.txt → VS Codium extensions (bare-metal only)
  ├── 13. Step 10: modules/fonts.sh      → Nerd Fonts installation
  ├── 14. Step 11: modules/distrobox.sh  → Distrobox containers provisioning
  ├── 15. Step 12: modules/post_install.sh → shell configs, git dotfiles & cleanup
  └── 16. Print summary (successes + failures)
```

The only difference between `fedora.sh` and `fedora_wsl.sh` is the `ENV` variable (`bare-metal` vs `wsl`), which filters packages tagged with `# bare-metal only` or `# wsl only` in the manifest files.

## Environment Tags

Packages in `packages/dnf.txt` can be tagged for a specific environment:

```ini
kitty                    # bare-metal only   ← skipped on WSL
btop                     # wsl only          ← skipped on bare-metal
ripgrep                  # no tag = installed everywhere
```

## Selective Step Execution

To support testing individual modules, debugging installation failures, or resuming interrupted installs, you can selectively control which setup steps run using command-line arguments.

### Execution Control Flags

* `--list`: Lists all available steps for the current environment (`bare-metal` or `wsl`) and exits.
* `--from <step>`: Starts execution from the specified step name or number (inclusive) and runs all subsequent steps.
* `--only <steps>`: Executes only the specified step name(s) or number(s). Multiple steps can be separated by commas.
* `--exclude <steps>`: Runs all steps except the specified step name(s) or number(s). Multiple steps can be separated by commas.

### Available Steps

Steps can be targeted using either their step number or their short step ID.

| Step # (Bare-Metal) | Step # (WSL) | Step ID | Description |
| :---: | :---: | :--- | :--- |
| **1** | **1** | `repos` | External repository configurations |
| **2** | **2** | `scripts` | Script-based binary installers |
| **3** | **3** | `copr` | COPR repository package installations |
| **4** | **4** | `dnf` | System packages bulk installation |
| **5** | **5** | `cargo` | Rust tool integrations |
| **6** | **6** | `flatpak` | Flatpak applications |
| **7** | **7** | `multimedia` | Codecs & drivers *(skipped on WSL)* |
| **8** | -- | `virtualization` | Virt manager & nested KVM |
| **9** | -- | `vscodium` | VS Codium extensions |
| **10** | **8** | `fonts` | Nerd Fonts installation |
| **11** | **9** | `distrobox` | Distrobox container provisioning |
| **12** | **10** | `post_install` | Dotfiles, default shell setup & cleanup |

### Advanced Examples

* **Resume install after a failure on Step 10**:
  ```bash
  ./fedora.sh --from 10
  ```
* **Test the virtualization and distrobox configurations only (using step IDs)**:
  ```bash
  ./fedora.sh --only virtualization,distrobox
  ```
* **Test the virtualization and distrobox configurations only (using step numbers)**:
  ```bash
  ./fedora.sh --only 8,11
  ```
* **Run the entire script but skip Flatpaks and Nerd Fonts (using step numbers)**:
  ```bash
  ./fedora.sh --exclude 6,10
  ```
* **Running via the one-liner command**:
  ```bash
  curl -sSf https://raw.githubusercontent.com/ThamizhiniyanCS/fedora/main/bootstrap.sh | bash -s -- --only distrobox
  ```

## Requirements

- Fedora (with DNF5)
- `curl` (pre-installed on Fedora)
- `sudo` access
