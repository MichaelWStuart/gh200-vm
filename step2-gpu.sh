#!/bin/bash
set -euo pipefail

echo "==== STEP 2: H100-COMPATIBLE DRIVER + CUDA 12.4 INSTALL ===="

# ─── Purge any old NVIDIA/CUDA apt sources & keys ────────────────────────
sudo rm -f /etc/apt/sources.list.d/*nvidia*.list \
          /etc/apt/keyrings/*nvidia*.gpg \
          /etc/apt/cloud-init.gpg.d/*nvidia*.gpg

# ─── Remove old driver & toolkit packages ───────────────────────────────
echo "🧹 Purging NVIDIA/CUDA packages…"
sudo apt-get update
sudo apt-get purge -y 'nvidia-*' 'cuda*' 'libcuda-*' || true
sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo rm -f /var/cache/apt/archives/*nvidia* *cuda*.deb
sudo dpkg --configure -a
sudo apt-get -f install -y

# ─── Install build tools & kernel headers ───────────────────────────────
echo "📦 Installing build tools & kernel headers…"
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  dkms \
  linux-headers-$(uname -r) \
  wget \
  gnupg \
  lsb-release \
  curl

# ─── Download & install the run-file driver (v570.124.06) ─────────────────
DRIVER_URL="https://us.download.nvidia.com/tesla/570.124.06/NVIDIA-Linux-aarch64-570.124.06.run"
DRIVER_RUN="/tmp/NVIDIA-driver-570.124.06.run"

echo "⬇️  Downloading NVIDIA run-file driver v570.124.06…"
curl -fsSL "$DRIVER_URL" -o "$DRIVER_RUN" && chmod +x "$DRIVER_RUN"

echo "🛠️ Installing NVIDIA driver (silent)…"
sudo bash "$DRIVER_RUN" --silent

# ─── Add CUDA 12.4 APT repo & install toolkit ───────────────────────────
echo "📖 Adding CUDA 12.4 APT repo (ARM64)…"
sudo install -m0755 -d /etc/apt/keyrings
curl -fsSL \
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/arm64/3bf863cc.pub \
  | sudo gpg --dearmor --batch --yes \
      -o /etc/apt/keyrings/cuda-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cuda-archive-keyring.gpg arch=arm64] \
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/arm64/ /" \
  | sudo tee /etc/apt/sources.list.d/cuda.list

sudo apt-get update
echo "📥 Installing CUDA 12.4 toolkit…"
sudo apt-get install -y cuda-toolkit-12-4

# ─── Configure environment (safe under set -u) ──────────────────────────
echo "🔧 Writing /etc/profile.d/cuda.sh…"
sudo tee /etc/profile.d/cuda.sh > /dev/null << 'EOF'
# CUDA 12.4 environment
export PATH=/usr/local/cuda-12.4/bin${PATH:+:$PATH}
export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
EOF

# shellcheck disable=SC1091
source /etc/profile.d/cuda.sh

# ─── Load kernel modules & validate ────────────────────────────────────
echo "🔄 Loading NVIDIA kernel modules…"
sudo modprobe nvidia || true
sudo modprobe nvidia_uvm || true

echo "🔧 Testing nvidia-smi…"
if ! nvidia-smi &> /dev/null; then
  echo "❌ nvidia-smi cannot see GPU—driver install incomplete."
  exit 1
fi

echo "🔧 Testing nvcc…"
if ! nvcc --version &> /dev/null; then
  echo "❌ nvcc not found—CUDA install incomplete."
  exit 1
fi

echo "🎉 NVIDIA driver + CUDA 12.4 installed and running cleanly."