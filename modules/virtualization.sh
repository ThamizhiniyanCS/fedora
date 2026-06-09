#!/bin/bash
# ==============================================================================
# Module: Virtualization & Nested Virtualization Setup
# ==============================================================================
# Installs virtualization tools, starts/enables libvirtd service, and sets up
# nested virtualization options for KVM based on AMD/Intel CPU detection.
#
# This module is BARE-METAL ONLY — the orchestrator should skip it for WSL.
#
# Expects:
#   - Helper functions (install, info, error, success) from lib/helpers.sh
# ==============================================================================

header "Setting up Virtualization & Nested Virtualization"

info "Installing virtualization group packages..."
sudo dnf group install -y --with-optional virtualization --allowerasing

info "Enabling and starting libvirtd service..."
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Enable nested virtualization
if grep -q -E "svm" /proc/cpuinfo; then
  info "Enabling nested virtualization for AMD CPU..."
  sudo modprobe -r kvm_amd || true
  sudo modprobe kvm_amd nested=1 || true
  sudo mkdir -p /etc/modprobe.d
  echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm.conf > /dev/null
elif grep -q -E "vmx" /proc/cpuinfo; then
  info "Enabling nested virtualization for Intel CPU..."
  sudo modprobe -r kvm_intel || true
  sudo modprobe kvm_intel nested=1 || true
  sudo mkdir -p /etc/modprobe.d
  echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm.conf > /dev/null
else
  info "Virtualization extensions not supported by the CPU, skipping nested virtualization config."
fi
