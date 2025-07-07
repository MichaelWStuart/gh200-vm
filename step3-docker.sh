#!/bin/bash
set -euo pipefail

echo "==== STEP 3: Docker CE + NVIDIA Container Toolkit (ARM64) ===="

# ─── Purge any old Docker/NVIDIA sources & keys ─────────────────────────
sudo rm -f /etc/apt/sources.list.d/docker.list \
          /etc/apt/keyrings/docker.gpg \
          /etc/apt/sources.list.d/*nvidia*.list \
          /etc/apt/keyrings/*nvidia*.gpg \
          /etc/apt/cloud-init.gpg.d/*nvidia*.gpg

sudo systemctl stop docker || true

# ─── Install Docker CE (ARM64) ─────────────────────────────────────────
echo "🐳 Installing Docker CE (ARM64)…"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# ─── Install NVIDIA Container Toolkit ──────────────────────────────────
echo "🧩 Installing NVIDIA Container Toolkit (ARM64)…"
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)   # e.g. ubuntu22.04

sudo install -m0755 -d /usr/share/keyrings
curl -fsSL \
  https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor --batch --yes \
      -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# **Use the distribution-specific list file (no “stable/deb/arm64”)**  [oai_citation:0‡docs.nvidia.com](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.10.0/install-guide.html)
curl -s -L \
  "https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list" \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# ─── Configure Docker runtime & validate ───────────────────────────────
echo "🛠️ Configuring Docker to use the NVIDIA runtime…"
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo "🧪 Verifying GPU access in a minimal CUDA container…"
sudo docker run --rm --gpus all --platform linux/arm64 \
  nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi

echo "✅ Docker + NVIDIA container toolkit installed and validated."