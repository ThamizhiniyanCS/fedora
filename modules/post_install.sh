#!/bin/bash
# ==============================================================================
# Module: Post-install Configuration
# ==============================================================================
# Runs after all packages are installed. Handles shell configuration,
# user messages, cleanup, and the final summary.
#
# Expects:
#   - ENV variable ("bare-metal" or "wsl") to be set by the orchestrator
#   - Helper functions from lib/helpers.sh
#   - FAILED_PACKAGES / SUCCEEDED_PACKAGES arrays from lib/helpers.sh
# ==============================================================================

header "Post-install configuration"

# --- Set default shell to fish ---
if command -v fish &>/dev/null; then
  info "Setting default shell to fish..."
  sudo chsh -s "$(which fish)"
  success "Default shell set to fish."
else
  error "Fish shell not found — skipping default shell change."
fi

# --- Proton VPN reminder (bare-metal only) ---
if [[ "$ENV" == "bare-metal" ]]; then
  echo ""
  info "╔══════════════════════════════════════════════════════════════════╗"
  info "║  PROTON VPN: Restart your computer, then open the Extensions   ║"
  info "║  app and ensure 'AppIndicator and KStatusNotifierItem Support'  ║"
  info "║  is toggled ON before launching Proton VPN.                    ║"
  info "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
fi

# --- Cleanup ---
info "Cleaning up temp directory..."
rm -rf /tmp/fedora-install-script/

# --- Final summary ---
print_summary
