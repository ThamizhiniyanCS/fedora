# Tasks — Modular Refactoring

## Phase 0: Bootstrap

- [x] **T0** — Create `bootstrap.sh`
  - Auto-detects WSL vs bare-metal
  - Downloads repo as tarball (no git needed)
  - Single curl one-liner for fresh systems

## Phase 1: Foundation

- [x] **T1** — Create `lib/helpers.sh` with shared functions
  - `info()`, `error()`, `success()` with color output
  - `install()` with failure tracking (`FAILED_PACKAGES` array)
  - `copr_enable()` with failure tracking
  - `parse_packages()` — reads manifest, filters by environment, skips comments
  - `install_from_manifest()` — bulk install from a manifest file
  - `print_summary()` — end-of-run success/failure report

## Phase 2: Package Manifests

- [x] **T2** — Create `packages/dnf.txt`
  - Extract all DNF packages from `fedora.sh` and `fedora_wsl.sh`
  - Organize into `[category]` sections
  - Tag environment-specific packages with `# bare-metal only` or `# wsl only`

- [x] **T3** — Create `packages/cargo.txt`
  - Extract: `eza`, `resvg`

- [x] **T4** — Create `packages/copr.txt`
  - Extract: `dejan/lazygit → lazygit`, `lihaohong/yazi → yazi`

- [x] **T5** — Create `packages/scripts.txt`
  - Extract: `rustup`, `starship`, `uv`, `bun`, `fnm`, `lazydocker`

- [x] **T6** — Create `packages/catalog.sh`
  - `PKG_DESC` associative array with descriptions for all ~35 packages
  - `PKG_URL` associative array with website/repo URLs for all packages

## Phase 3: Modules

- [x] **T7** — Create `modules/repos.sh`
  - GitHub CLI repo setup
  - VSCodium repo setup
  - DangerZone repo setup (bare-metal only)
  - Proton VPN repo setup (bare-metal only)

- [x] **T8** — Create `modules/multimedia.sh`
  - RPM Fusion multimedia group install
  - ffmpeg swap
  - Additional codec install
  - AMD mesa driver swap
  - NVIDIA libva driver install

- [x] **T9** — Create `modules/post_install.sh`
  - Set default shell to fish
  - Print Proton VPN restart message (bare-metal only)
  - Cleanup temp directory
  - Print summary

## Phase 4: Orchestrators

- [x] **T10** — Rewrite `fedora.sh` as thin orchestrator
  - Set `ENV=bare-metal`
  - Source helpers + catalog
  - Call modules and manifest parsers in order
  - Supports `--info` dry-run flag

- [x] **T11** — Rewrite `fedora_wsl.sh` as thin orchestrator
  - Set `ENV=wsl`
  - Source same helpers + catalog
  - Skips multimedia module
  - Supports `--info` dry-run flag

## Phase 5: Polish

- [x] **T12** — Add `--info` flag support
  - `print_info()` in `lib/helpers.sh` — parses all manifests, prints formatted table
  - Wired into both orchestrators via `--info` CLI arg

- [x] **T13** — Verify completeness
  - All DNF, COPR, cargo, and script-based packages verified — zero missing

- [x] **T14** — Create project `README.md`

---

## Progress

| Phase | Tasks | Done |
|---|---|---|
| 0. Bootstrap | T0 | 1/1 |
| 1. Foundation | T1 | 1/1 |
| 2. Manifests | T2–T6 | 5/5 |
| 3. Modules | T7–T9 | 3/3 |
| 4. Orchestrators | T10–T11 | 2/2 |
| 5. Polish | T12–T14 | 3/3 |
| **Total** | **T0–T14** | **15/15 ✅** |
