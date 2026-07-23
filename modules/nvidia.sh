#!/bin/bash
# ==============================================================================
# Module: NVIDIA GPU Driver Installation
# ==============================================================================
# Installs NVIDIA GPU drivers and CUDA toolkit for bare-metal Fedora.
#
# This module is BARE-METAL ONLY — the orchestrator should skip it for WSL.
#
# Two driver stacks are installed:
#   1. RPM Fusion akmod-nvidia — community-maintained, auto-rebuilds on kernel
#      updates via akmods (recommended for most desktop users).
#   2. NVIDIA official open kernel modules + CUDA toolkit — from NVIDIA's own
#      Fedora repo, required for CUDA development and data-center workloads.
#
# References:
#   - https://docs.fedoraproject.org/en-US/gaming/drivers/
#   - https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/fedora.html
#   - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#fedora-installation
#
# Expects:
#   - Helper functions (install, info, error, success) from lib/helpers.sh
#   - RPM Fusion repos already enabled (handled by multimedia.sh / repos.sh)
# ==============================================================================

header "Installing NVIDIA GPU drivers"

# ==============================================================================
# 1. RPM Fusion — akmod-nvidia (auto-rebuilding kernel module)
# ==============================================================================
info "Ensuring RPM Fusion repositories are enabled..."
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
  || info "RPM Fusion repos already present or failed to add — continuing."

info "Installing akmod-nvidia from RPM Fusion..."
install akmod-nvidia

# ==============================================================================
# 2. NVIDIA Official Repo — open kernel modules + CUDA toolkit
# ==============================================================================
info "Installing kernel development headers..."
sudo dnf install -y kernel-devel-matched kernel-headers

info "Adding NVIDIA CUDA repository..."
export fedora_version=$(cut -d' ' -f3 /etc/fedora-release)
sudo dnf config-manager addrepo \
  --from-repofile="https://developer.download.nvidia.com/compute/cuda/repos/fedora${fedora_version}/$(uname -m)/cuda-fedora${fedora_version}.repo" \
  || info "NVIDIA CUDA repo already present or failed to add — continuing."

info "Cleaning DNF cache..."
sudo dnf clean expire-cache

info "Installing NVIDIA open kernel modules..."
sudo dnf install -y nvidia-open --allowerasing || info "nvidia-open install failed — may conflict with akmod-nvidia. Continuing."

info "Installing NVIDIA driver, DKMS modules, and CUDA toolkit..."
sudo dnf install -y nvidia-driver kmod-nvidia-open-dkms cuda-toolkit || info "Some NVIDIA/CUDA packages failed to install. Continuing."

