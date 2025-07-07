#!/bin/bash
set -euo pipefail

sudo apt update
sudo apt install -y \
  build-essential \
  dkms \
  curl \
  gcc \
  make \
  linux-headers-$(uname -r) \
  git \
  python3-pip \
  python3-venv \
  python3-dev

echo "Rebooting to apply kernel headers..."
echo "__REBOOT__"
sudo reboot