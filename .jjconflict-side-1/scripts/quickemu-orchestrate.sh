#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

printf "%s\n" "[1/3] Building ISO"
./scripts/build-iso.sh

ISO_RESULT="./result/iso"
ISO_PATH=$(ls -1 "$ISO_RESULT"/*.iso 2>/dev/null | head -n1 || true)
if [ -z "$ISO_PATH" ]; then
  printf "%s\n" "No ISO found after build" 1>&2
  exit 1
fi

printf "%s\n" "[2/3] Launching VM with Quickemu"
./scripts/quickemu-run.sh "$ISO_PATH" &
VM_PID=$!

sleep 3

printf "%s\n" "[3/3] Running SSH smoke test"
./scripts/quickemu-smoke-ssh.sh || {
  printf "%s\n" "Smoke test failed" 1>&2
  exit 1
}

# Request graceful shutdown via Quickemu monitor
printf "%s\n" "Requesting VM shutdown via Quickemu monitor"
quickemu --vm nixos-installer.conf --monitor-cmd system_powerdown >/dev/null 2>&1 || true

# Wait for process to exit
if [ -n "${VM_PID:-}" ]; then
  i=0
  while kill -0 "$VM_PID" 2>/dev/null; do
    i=$((i+1))
    if [ "$i" -gt 60 ]; then
      printf "%s\n" "Timeout waiting for VM to power down; sending SIGTERM" 1>&2
      kill "$VM_PID" 2>/dev/null || true
      break
    fi
    sleep 2
  done
fi

printf "%s\n" "Smoke test passed (sshd listening) and VM powered down."

