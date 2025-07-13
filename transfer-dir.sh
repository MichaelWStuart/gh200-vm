#!/bin/bash
set -euo pipefail

# Defaults
VM_IP=""
MODEL_DIR=""

# Usage
usage() {
  echo "Usage: $0 --ip <VM_IP> --d <MODEL_DIR>"
  exit 1
}

# Parse arguments
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
      usage
      ;;
  esac
done

# Validate arguments
if [[ -z "$VM_IP" || -z "$MODEL_DIR" ]]; then
  usage
fi

# Script and file directory
SCRIPT_PATH="$HOME/gh200-vm/transfer-file.sh"
FILES_DIR="$HOME/Downloads/$MODEL_DIR"

# Loop through all files and open new terminal tab per file
for FILE in "$FILES_DIR"/*; do
  FILE_NAME=$(basename "$FILE")
  osascript <<EOF
  tell application "Terminal"
    activate
    do script "bash '$SCRIPT_PATH' --ip '$VM_IP' --d '$MODEL_DIR' '$FILE_NAME'"
  end tell
EOF
done