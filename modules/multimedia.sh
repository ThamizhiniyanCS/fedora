#!/bin/bash
# ==============================================================================
# Module: Multimedia & Codec Setup
# ==============================================================================
# Sets up multimedia codecs, swaps free for full implementations, and installs
# hardware-accelerated video drivers.
#
# This module is BARE-METAL ONLY — the orchestrator should skip it for WSL.
#
# Reference: https://rpmfusion.org/Howto/Multimedia
#
# Expects:
#   - Helper functions (install, info, error, success) from lib/helpers.sh
# ==============================================================================

header "Setting up multimedia and codecs"

# --- Multimedia group install ---
info "Installing multimedia group packages..."
sudo dnf group install -y --with-optional multimedia --allowerasing

# --- Switch to full ffmpeg ---
info "Swapping ffmpeg-free for full ffmpeg..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

# --- Additional codecs ---
info "Installing additional codecs..."
sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

# --- Hardware codecs: AMD (mesa) ---
info "Installing AMD hardware codec drivers (mesa)..."
sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld

# --- Hardware codecs: NVIDIA ---
info "Installing NVIDIA hardware codec drivers..."
install libva-nvidia-driver.{i686,x86_64}
