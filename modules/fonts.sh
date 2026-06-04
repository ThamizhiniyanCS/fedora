#!/bin/bash
# ==============================================================================
# Module: Nerd Fonts Installation
# ==============================================================================
# Downloads and installs Nerd Fonts into the user's local fonts directory.
# Add more fonts by appending entries to the FONTS array below.
#
# Expects:
#   - Helper functions (info, error, success) from lib/helpers.sh
# ==============================================================================

header "Installing Nerd Fonts"

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# ── Font list ─────────────────────────────────────────────────────────────────
# Add more Nerd Fonts here by name (must match the release asset filename)
# Full list: https://github.com/ryanoasis/nerd-fonts/releases/latest
FONTS=(
  "CascadiaCode"
)

NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

for font in "${FONTS[@]}"; do
  if ls "$FONT_DIR"/${font}*.ttf &>/dev/null || ls "$FONT_DIR"/${font}*.otf &>/dev/null; then
    info "$font is already installed — skipping."
    continue
  fi

  info "Downloading $font Nerd Font..."
  if wget -q -P "$FONT_DIR" "${NERD_FONTS_BASE_URL}/${font}.zip"; then
    unzip -o -q "$FONT_DIR/${font}.zip" -d "$FONT_DIR"
    rm -f "$FONT_DIR/${font}.zip"
    success "Successfully installed font: $font"
  else
    error "Failed to download font: $font"
    FAILED_PACKAGES+=("font:$font")
  fi
done

# Rebuild font cache
info "Rebuilding font cache..."
fc-cache -fv
