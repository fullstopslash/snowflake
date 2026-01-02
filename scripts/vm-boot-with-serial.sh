#!/usr/bin/env nix-shell
#!nix-shell -i bash -p qemu swtpm

# Boot VM with serial console for automated password entry
# Usage: vm-boot-with-serial.sh <hostname>

set -euo pipefail

HOST="${1:-sorrow}"
QCOW2="quickemu/${HOST}-test.qcow2"
PID_FILE="quickemu/${HOST}-test.pid"
SERIAL_LOG="quickemu/${HOST}-serial.log"

if [ ! -f "$QCOW2" ]; then
    echo "❌ No disk image found: $QCOW2"
    exit 1
fi

if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
    echo "VM $HOST is already running (PID: $(cat "$PID_FILE"))"
    exit 0
fi

echo "🚀 Starting VM $HOST with serial console..."

OVMF_PATH=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link 2>/dev/null)
OVMF_CODE="$OVMF_PATH/FV/OVMF_CODE.fd"
OVMF_VARS="quickemu/${HOST}-OVMF_VARS.fd"

# Setup TPM
TPM_STATE_DIR="quickemu/${HOST}-tpm"
TPM_SOCKET="quickemu/${HOST}-tpm.sock"
mkdir -p "$TPM_STATE_DIR"
rm -f "$TPM_SOCKET"

# Start TPM emulator (log level 0 = minimal logging)
swtpm socket \
    --tpmstate dir="$TPM_STATE_DIR" \
    --ctrl type=unixio,path="$TPM_SOCKET" \
    --tpm2 \
    --log level=0 &

SWTPM_PID=$!
echo "🔐 TPM emulator started (PID: $SWTPM_PID)"

# Wait for TPM socket
for i in {1..10}; do
    [ -S "$TPM_SOCKET" ] && break
    sleep 0.1
done

# Boot with serial console redirected to stdio (for expect interaction)
qemu-system-x86_64 \
    -name "${HOST}-test" \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -cpu host,topoext \
    -smp cores=2,threads=2,sockets=1 \
    -m 8G \
    -pidfile "$PID_FILE" \
    -nographic \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device virtio-net,netdev=nic \
    -netdev "user,hostname=${HOST},hostfwd=tcp::22222-:22,restrict=off,id=nic" \
    -chardev socket,id=chrtpm,path="$TPM_SOCKET" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
    -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" \
    -serial mon:stdio

echo "VM exited"
