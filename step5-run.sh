#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <VM_IP>"
  exit 1
}

# require exactly one argument
if [ "$#" -ne 1 ]; then
  usage
fi

VM_IP="$1"
VM_USER="ubuntu"
SSH_KEY="$HOME/.ssh/id_ed25519"

# Configurable
HOST="localhost"
PORT="8188"
PROTOCOL="http"
URL="${PROTOCOL}://${HOST}:${PORT}"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q '^2'; then
  echo "✅ ComfyUI is already running and responding on $URL"
else
  CONTAINER_NAME="comfy_default"

  echo "🚀 Launching ComfyUI inside container $CONTAINER_NAME..."
  ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" "
    sudo docker exec -d $CONTAINER_NAME bash -c '
      source \$HOME/comfy-venv/bin/activate && \
      cd \$HOME/comfy/ComfyUI && \
      python3 main.py --listen 0.0.0.0 --port $PORT
    '
  " || true

  if ! pgrep -f "ssh .* -L $PORT:$HOST:$PORT" >/dev/null; then
    echo "🔗 Opening SSH tunnel (${HOST}:${PORT} → ${VM_IP}:${PORT})..."
    ssh "${SSH_OPTS[@]}" -fN -L "$PORT:$HOST:$PORT" "${VM_USER}@${VM_IP}"
  fi

  echo -n "⏳ Waiting for ComfyUI to become available"
  for i in $(seq 1 24); do
    if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q '^2'; then
      echo " — up!"
      break
    fi
    echo -n "."
    sleep 5
  done
fi

if ! pgrep -f "open $URL|xdg-open $URL" >/dev/null; then
  echo "🌐 Opening your browser to $URL"
  if command -v open &>/dev/null; then
    open "$URL"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$URL"
  else
    echo "Please navigate your browser to $URL"
  fi
else
  echo "🌐 Browser already opened"
fi