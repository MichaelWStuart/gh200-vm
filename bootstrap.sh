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

SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

export VM_IP
export VM_USER
export SSH_KEY
export SSH_OPTS

wait_for_ssh() {
  echo -n "Waiting for VM to come back online"
  for _ in $(seq 1 60); do
    sleep 5
    if ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" 'echo OK' &>/dev/null; then
      echo " — VM online."
      return
    fi
    echo -n "."
  done
  echo " timed out."
  exit 1
}

run_step() {
  local script="$1"
  echo "▶️ Running $script..."
  if [ "$script" = "step5-run.sh" ]; then
    bash "./$script" "$VM_IP"
  else
    set +e
    ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" "VM_IP='$VM_IP' VM_USER='$VM_USER' SSH_KEY='$SSH_KEY' bash ~/${script}"
    local status=$?
    set -e

    if [ $status -eq 255 ]; then
      echo "🔄 Detected reboot, waiting..."
      wait_for_ssh
    elif [ $status -eq 42 ]; then
      echo "🔄 Detected driver reinstall and reboot request from $script..."
      wait_for_ssh
      echo "🔁 Re-running $script after reboot..."
      run_step "$script"
    elif [ $status -ne 0 ]; then
      echo "❌ $script failed with exit code $status"
      exit $status
    fi
  fi
}

scp "${SSH_OPTS[@]}" step1-os.sh step2-gpu.sh step3-docker.sh step4-comfyui.sh "${VM_USER}@${VM_IP}":~/
ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" "chmod +x ~/step1-os.sh ~/step2-gpu.sh ~/step3-docker.sh ~/step4-comfyui.sh"

run_step step1-os.sh
run_step step2-gpu.sh
run_step step3-docker.sh
run_step step4-comfyui.sh
run_step step5-run.sh

echo "✅ All steps complete."