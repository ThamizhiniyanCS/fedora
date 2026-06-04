# Session Context

> Use this file to resume work in a new session. Paste it or reference it at the start of a new conversation.

## Project

**Repository:** `os-init-scripts` — Bash scripts to bootstrap a fresh Fedora (bare-metal and WSL) installation with all preferred tools and configuration.

## What Was Done

Refactored `fedora.sh` (334 lines) and `fedora_wsl.sh` (252 lines) from monolithic scripts into a **data-driven, modular architecture**:

### New Structure
```
os-init-scripts/
├── bootstrap.sh              # curl one-liner entry point, auto-detects WSL
├── lib/helpers.sh             # Shared functions: logging, install wrappers, parsers, --info, summary
├── packages/
│   ├── dnf.txt                # 23 DNF packages in 7 [categories] with env tags
│   ├── cargo.txt              # 2 cargo packages (eza, resvg)
│   ├── copr.txt               # 2 COPR mappings (lazygit, yazi)
│   ├── scripts.txt            # 6 curl-based installers (rustup, starship, uv, bun, fnm, lazydocker)
│   └── catalog.sh             # PKG_DESC + PKG_URL associative arrays for all ~35 tools
├── modules/
│   ├── repos.sh               # External repo setup (gh, vscodium, dangerzone, protonvpn)
│   ├── multimedia.sh          # Codecs, ffmpeg swap, AMD/NVIDIA HW drivers (bare-metal only)
│   └── post_install.sh        # Fish shell default, ProtonVPN reminder, cleanup, summary
├── fedora.sh                  # Thin orchestrator (ENV=bare-metal), supports --info
├── fedora_wsl.sh              # Thin orchestrator (ENV=wsl), skips multimedia
├── PLAN.md                    # Implementation plan
├── TASKS.md                   # Task tracker (14/15 done)
└── CONTEXT.md                 # This file
```

### Key Design Decisions
1. **Text files over JSON** — `jq` isn't available on a fresh system
2. **Option B (lean manifests + catalog)** — manifests are scannable (~30 lines), catalog provides queryable documentation
3. **INI-style `[category]` headers** with `# bare-metal only` / `# wsl only` environment tags
4. **`curl | sh` scripts kept as-is** (convenience over security)
5. **Bootstrap via tarball download** — no git needed on fresh systems

### Verification
- All ~35 packages verified present across manifests/modules — zero missing vs original scripts
- `--info` dry-run flag implemented in both orchestrators

## Current State

**14/15 tasks complete.** Remaining:
- **T14** — Update project `README.md` (optional)

## Files to Reference
- `PLAN.md` — full implementation plan
- `TASKS.md` — task tracker with progress
