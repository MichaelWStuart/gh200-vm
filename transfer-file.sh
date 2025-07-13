#!/usr/bin/env bash
# transfer.sh – copy a single model file laptop → VM → Docker container
# Usage: ./transfer.sh --ip <VM_IP> --d <MODEL_DIR> <filename.category>

set -euo pipefail

###############################################################################
# CONFIG – change once
###############################################################################
VM_USER="ubuntu"
SSH_KEY="$HOME/.ssh/id_ed25519"
CONTAINER_NAME="comfy_default"

REMOTE_TMP_DIR="/home/$VM_USER/tmp_models"
CONTAINER_MODEL_DIR="/root/comfy/ComfyUI/models"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

###############################################################################
# ARGUMENT PARSING
###############################################################################

VM_IP=""
MODEL_DIR=""
FILENAME=""

usage() {
  echo "Usage: $0 --ip <VM_IP> --d <MODEL_DIR> <filename.category>"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --ip)
      VM_IP="$2"
      shift 2
      ;;
    --d)
      MODEL_DIR="$2"
      shift 2
      ;;
    *)
      if [[ -z "$FILENAME" ]]; then
        FILENAME="$1"
        shift
      else
        usage
      fi
      ;;
  esac
done

if [[ -z "$VM_IP" || -z "$MODEL_DIR" || -z "$FILENAME" ]]; then
  usage
fi

###############################################################################
# MAIN
###############################################################################

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

category="${FILENAME##*.}"   # loras
file="${FILENAME%.*}"        # mylora.safetensors

local_path="$HOME/Downloads/$MODEL_DIR/$FILENAME"
remote_tmp="$REMOTE_TMP_DIR/${category}--$file"
container_dest="$CONTAINER_MODEL_DIR/$category/$file"

[ -f "$local_path" ] || { echo "❌ File not found: $local_path"; exit 1; }

log "Ensuring tmp dir $REMOTE_TMP_DIR on VM…"
ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" "mkdir -p '$REMOTE_TMP_DIR'"

# ── copy laptop → VM ─────────────────────────────────────────────────────────
if ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" "[ -f '$remote_tmp' ]"; then
  log "$file already in VM staging dir, skipping upload"
else
  log "Copying $file → VM"
  scp "${SSH_OPTS[@]}" "$local_path" "$VM_USER@$VM_IP:$remote_tmp"
fi

# ── move VM → container ──────────────────────────────────────────────────────
log "Copying (if needed) into container $CONTAINER_NAME …"

ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" bash -s -- "$category" "$file" <<'VM'
set -euo pipefail

category="$1"
file="$2"

CONTAINER_NAME="comfy_default"
REMOTE_TMP_DIR="$HOME/tmp_models"
CONTAINER_MODEL_DIR="/root/comfy/ComfyUI/models"

remote_tmp="$REMOTE_TMP_DIR/${category}--${file}"
container_dest="$CONTAINER_MODEL_DIR/$category/$file"

if sudo docker exec "$CONTAINER_NAME" test -f "$container_dest"; then
  echo "[INFO] $file already exists in container, deleting temp copy"
  rm -f -- "$remote_tmp"
  exit 0
fi

echo "[INFO] Copying $file → container path $container_dest"
sudo docker exec "$CONTAINER_NAME" mkdir -p "$CONTAINER_MODEL_DIR/$category"
sudo docker cp -- "$remote_tmp" "$CONTAINER_NAME:$container_dest"
rm -f -- "$remote_tmp"
echo "[INFO] Done."
VM

log "✅ Transfer complete"