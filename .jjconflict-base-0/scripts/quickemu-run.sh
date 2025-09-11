#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

ISO_RESULT="./result/iso" # from build script
ISO_PATH="${1:-}"

if [ -z "$ISO_PATH" ]; then
  if [ -d "$ISO_RESULT" ]; then
    ISO_PATH=$(ls -1 "$ISO_RESULT"/*.iso 2>/dev/null | head -n1 || true)
  fi
fi

if [ ! -f "$ISO_PATH" ]; then
  printf "%s\n" "ISO not found. Build first: ./scripts/build-iso.sh" 1>&2
  exit 1
fi

VM_NAME="nixos-installer"
DISK_IMG="./.quickemu/${VM_NAME}.qcow2"
mkdir -p "$(dirname "$DISK_IMG")"

cat >"${VM_NAME}.conf" <<EOF
guest_os="linux"
disk_img="$DISK_IMG"
disk_size="32G"
cpu_cores="4"
ram="4096"
iso="$ISO_PATH"
ssh_port="2222"
EOF

printf "%s\n" "Launching Quickemu VM ($VM_NAME) with ISO: $ISO_PATH"

# Ensure any previous instance is stopped
quickemu --vm "${VM_NAME}.conf" --kill >/dev/null 2>&1 || true

quickemu --vm "${VM_NAME}.conf" --display none


