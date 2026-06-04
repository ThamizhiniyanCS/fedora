# Implementation Plan — Modular Refactoring of `fedora.sh`

## Goal

Refactor the monolithic `fedora.sh` (and `fedora_wsl.sh`) into a **data-driven, modular architecture** where:

- All packages are declared in lean manifest files (`packages/*.txt`)
- Documentation lives in a sourceable catalog (`packages/catalog.sh`)
- Shared logic lives in `lib/helpers.sh`
- The main scripts become thin orchestrators
- `fedora.sh` and `fedora_wsl.sh` share ~95% of their code

## Target Directory Structure

```
os-init-scripts/
├── lib/
│   └── helpers.sh                # Shared functions: install, copr_enable, parse_packages, etc.
├── packages/
│   ├── dnf.txt                   # All DNF packages, categorized with [section] headers
│   ├── cargo.txt                 # Cargo packages
│   ├── copr.txt                  # COPR repo → package mappings
│   ├── scripts.txt               # curl-based installer definitions
│   └── catalog.sh                # Descriptions & URLs (bash associative arrays)
├── modules/
│   ├── repos.sh                  # External repository setup (gh-cli, vscodium, dangerzone, protonvpn)
│   ├── multimedia.sh             # Multimedia/codec setup (RPM Fusion, ffmpeg swap, HW codecs)
│   └── post_install.sh           # Post-install config (default shell, messages, cleanup)
├── fedora.sh                     # Main orchestrator — bare-metal
├── fedora_wsl.sh                 # Main orchestrator — WSL (sources same libs)
├── PLAN.md
├── TASKS.md
└── CONTEXT.md
```

## Design Decisions

### 1. Package Manifests (Option B — lean manifests + catalog)

**Manifest files** (`packages/dnf.txt`, etc.) contain only package names and category headers — optimized for scanning and parsing:

```ini
[cli-tools]
ripgrep
fd-find
jq
zoxide
```

**Catalog file** (`packages/catalog.sh`) holds descriptions and URLs in bash associative arrays — sourceable, queryable, and usable for `--info` output:

```bash
declare -A PKG_DESC=(
  [ripgrep]="Recursively search directories for a regex pattern"
)
declare -A PKG_URL=(
  [ripgrep]="https://github.com/BurntSushi/ripgrep"
)
```

### 2. Environment Filtering

Packages tagged `# bare-metal only` or `# wsl only` in manifests are filtered by the orchestrator based on which script is run. The parser strips inline comments and skips environment-mismatched packages.

### 3. Error Handling

- `set -euo pipefail` at the top of every script
- Failed packages are collected into a `FAILED_PACKAGES` array
- A summary is printed at the end showing all successes and failures
- `dnf check-update` exit code 100 (updates available) is handled gracefully

### 4. Script-based Installs (`curl | sh`)

Kept as-is for now (convenience over security). Each entry in `packages/scripts.txt` uses a pipe-delimited format:

```
name | install_command
```

### 5. Shared Code

Both `fedora.sh` and `fedora_wsl.sh` source `lib/helpers.sh` and the same modules. The only difference is the `ENV` variable (`bare-metal` vs `wsl`), which controls package filtering.

## Execution Flow

```
fedora.sh (or fedora_wsl.sh)
  │
  ├── 1. Source lib/helpers.sh
  ├── 2. Source packages/catalog.sh
  ├── 3. Create temp dir, run dnf check-update
  ├── 4. Source modules/repos.sh        → set up external repos
  ├── 5. Parse packages/scripts.txt     → run curl-based installs (rustup, starship, etc.)
  ├── 6. Parse packages/copr.txt        → enable COPRs and install their packages
  ├── 7. Parse packages/dnf.txt         → bulk dnf install (filtered by ENV)
  ├── 8. Parse packages/cargo.txt       → cargo install each package
  ├── 9. Source modules/multimedia.sh   → codec/driver setup (bare-metal only)
  ├── 10. Source modules/post_install.sh → shell config, cleanup, messages
  └── 11. Print summary (successes + failures)
```

## What Changes for the User

| Action | Before | After |
|---|---|---|
| See all packages | Scroll 334 lines | Open `packages/dnf.txt` (~30 lines) |
| Add a DNF package | Write 4-line comment + `install` call | Add 1 line to `dnf.txt` + 1 entry in `catalog.sh` |
| Add a cargo package | Find the right spot, write comment + `cargo install` | Add 1 line to `cargo.txt` + 1 entry in `catalog.sh` |
| Share code fedora↔WSL | Copy-paste | Automatic (shared `lib/` and `packages/`) |
| See what failed | Scroll terminal output | Summary table at the end |
| Preview what will install | Not possible | `./fedora.sh --info` |
