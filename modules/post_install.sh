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
  sudo chsh -s "$(which fish)" "$USER"
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

# --- Setup Dotfiles ---
info "Setting up bare git repository for dotfiles..."

cd "$HOME" || { error "Failed to change directory to $HOME"; exit 1; }

info "Adding .git.dotfiles to .gitignore..."
echo ".git.dotfiles" >> .gitignore

info "Cloning dotfiles bare repository..."
git clone --bare https://github.com/ThamizhiniyanCS/dotfiles.git "$HOME/.git.dotfiles"

# Use a function instead of alias since aliases are disabled in non-interactive scripts by default
dotfiles() {
  /usr/bin/git --git-dir="$HOME/.git.dotfiles/" --work-tree="$HOME" "$@"
}

info "Checking out dotfiles (overwriting conflicting files if necessary)..."
dotfiles checkout 2>&1 | grep -E "\s+\." | awk {'print $1'} | xargs -I {} rm -rf {} || true
dotfiles checkout

info "Configuring dotfiles repo to ignore untracked files..."
dotfiles config --local status.showUntrackedFiles no
success "Dotfiles configured successfully."

# --- Final summary ---
print_summary
