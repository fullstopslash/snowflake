#!/usr/bin/env nix-shell
#!nix-shell -i bash -p qemu coreutils

# Start a headless QEMU VM for testing NixOS configurations
# Usage: ./start-vm-headless.sh <hostname> [ssh-port] [memory-gb]

HOSTNAME="${1:-griefling}"
SSH_PORT="${2:-22221}"
MEMORY="${3:-16}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_DIR="$REPO_ROOT/quickemu"

cd "$REPO_ROOT" || exit 1
mkdir -p "$VM_DIR"

# VM file paths
QCOW2="$VM_DIR/${HOSTNAME}-test.qcow2"
OVMF_VARS="$VM_DIR/${HOSTNAME}-OVMF_VARS.fd"
PID_FILE="$VM_DIR/${HOSTNAME}-test.pid"
MONITOR_SOCK="$VM_DIR/${HOSTNAME}-test-monitor.socket"
SERIAL_SOCK="$VM_DIR/${HOSTNAME}-test-serial.socket"

# Check if VM is already running
if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
    echo "VM $HOSTNAME is already running (PID: $(cat "$PID_FILE"))"
    exit 1
fi

# Create QCOW2 if it doesn't exist
if [ ! -f "$QCOW2" ]; then
    echo "Creating disk image for $HOSTNAME..."
    qemu-img create -f qcow2 "$QCOW2" 100G
fi

# Create OVMF_VARS if it doesn't exist
if [ ! -f "$OVMF_VARS" ]; then
    echo "Creating UEFI variables file for $HOSTNAME..."
    OVMF_CODE=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link)/FV/OVMF_VARS.fd
    cp "$OVMF_CODE" "$OVMF_VARS"
    chmod u+w "$OVMF_VARS"
fi

# Find OVMF_CODE
OVMF_CODE=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link)/FV/OVMF_CODE.fd

echo "Starting $HOSTNAME VM (headless, SSH on port $SSH_PORT)..."

qemu-system-x86_64 \
    -name "${HOSTNAME}-test,process=${HOSTNAME}-test" \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host,topoext \
    -smp cores=2,threads=2,sockets=1 \
    -m "${MEMORY}G" \
    -device virtio-balloon \
    -pidfile "$PID_FILE" \
    -rtc base=utc,clock=host \
    -display none \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device virtio-net,netdev=nic \
    -netdev "user,hostname=${HOSTNAME}-test,hostfwd=tcp::${SSH_PORT}-:22,id=nic" \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
    -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" \
    -monitor "unix:$MONITOR_SOCK,server,nowait" \
    -serial "unix:$SERIAL_SOCK,server,nowait" \
    -daemonize

echo "✅ VM $HOSTNAME started (PID: $(cat "$PID_FILE"))"
echo "   SSH: ssh -p $SSH_PORT root@127.0.0.1"
