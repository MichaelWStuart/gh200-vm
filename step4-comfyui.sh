#!/bin/bash
set -euo pipefail

CONTAINER_NAME="comfy_default"

echo "📦 Creating container: $CONTAINER_NAME"

# 1) Remove any existing container
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "🗑️  Removing existing container: $CONTAINER_NAME"
  sudo docker stop "$CONTAINER_NAME" || true
  sudo docker rm   "$CONTAINER_NAME" || true
fi

# 2) Save container name
echo "CONTAINER_NAME=$CONTAINER_NAME" > "$HOME/container.env"

# 3) Launch ARM64 CUDA base container
sudo docker run -d --gpus all \
  --name "$CONTAINER_NAME" \
  -p 8188:8188 \
  --restart unless-stopped \
  nvidia/cuda:12.4.1-runtime-ubuntu22.04 sleep infinity

echo "🚧 Installing ComfyUI, Python deps & PyTorch inside container…"
sudo docker exec "$CONTAINER_NAME" bash -lc '
  set -euo pipefail

  export DEBIAN_FRONTEND=noninteractive

  # Preseed tzdata (so python3 install won’t hang)
  apt-get update
  apt-get install -y tzdata
  ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
  dpkg-reconfigure --frontend noninteractive tzdata

  # Install system packages
  apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    expect

  # Create and activate virtualenv
  python3 -m venv /root/comfy-venv
  source /root/comfy-venv/bin/activate

  # Upgrade pip and install PyTorch for CUDA 12.4
  pip install --upgrade pip
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124

  # Install comfy-cli and run the interactive installer in expect
  pip install comfy-cli
  cat > /tmp/comfy_install.expect <<EOF
#!/usr/bin/expect -f
spawn comfy install
expect "Do you agree to enable tracking*"               { send "N\r" }
expect "What GPU do you have*"                          { send "nvidia\r" }
expect "Install from https://github.com/comfyanonymous/ComfyUI to */ComfyUI*" { send "y\r" }
expect eof
EOF
  chmod +x /tmp/comfy_install.expect
  expect /tmp/comfy_install.expect
  rm /tmp/comfy_install.expect

  # **Install ComfyUI’s requirements (einops, aiohttp, etc.)**
  cd /root/comfy/ComfyUI
  pip install -r requirements.txt

  # Then install custom-nodes manager
  cd custom_nodes
  git clone https://github.com/ltdrdata/ComfyUI-Manager.git || (cd ComfyUI-Manager && git pull)
  cd ComfyUI-Manager
  pip install -r requirements.txt || true

  deactivate
'

# 4) Validate CUDA & PyTorch support
sudo docker exec "$CONTAINER_NAME" bash -lc '
  source /root/comfy-venv/bin/activate
  python3 - <<EOF
import torch
print("torch version:", torch.__version__)
print("cuda available:", torch.cuda.is_available())
EOF
  deactivate
'

echo "✅ ComfyUI installation complete and running on ARM64/CUDA 12.4."