#!/usr/bin/env nix-shell
#!nix-shell -i bash -p qemu coreutils

# Start a GUI QEMU VM for testing NixOS configurations
# Usage: ./start-vm-gui.sh <hostname> [ssh-port] [memory-gb]

# Check if running over SSH
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    echo "Error: This script requires a local display. Use start-vm-headless.sh for SSH access."
    exit 1
fi

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
BOOT_FROM_ISO=false
if [ ! -f "$QCOW2" ]; then
    echo "Creating disk image for $HOSTNAME..."
    qemu-img create -f qcow2 "$QCOW2" 100G
    BOOT_FROM_ISO=true
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

echo "Starting $HOSTNAME VM (GUI, SSH on port $SSH_PORT)..."

# Build ISO if booting from scratch and it doesn't exist
ISO_PATH="$REPO_ROOT/result/iso/nixos-minimal-*.iso"
if [ "$BOOT_FROM_ISO" = true ]; then
    if ! compgen -G "$ISO_PATH" > /dev/null; then
        echo "Building minimal installer ISO..."
        cd "$REPO_ROOT/nixos-installer" && just iso
        cd "$REPO_ROOT"
    fi
    ISO_DRIVE=(-drive "media=cdrom,index=0,file=$(compgen -G "$ISO_PATH" | head -1)")
    echo "  Booting from ISO for initial installation"
else
    ISO_DRIVE=()
    echo "  Booting from existing disk"
fi

exec qemu-system-x86_64 \
    -name "${HOSTNAME}-test,process=${HOSTNAME}-test" \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host,topoext \
    -smp cores=2,threads=2,sockets=1 \
    -m "${MEMORY}G" \
    -device virtio-balloon \
    -pidfile "$PID_FILE" \
    -rtc base=utc,clock=host \
    -vga none \
    -device virtio-vga-gl,xres=1920,yres=1080 \
    -display sdl,gl=on \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device qemu-xhci,id=spicepass \
    -device usb-ehci,id=input \
    -device usb-kbd,bus=input.0 \
    -k en-us \
    -device usb-tablet,bus=input.0 \
    -audiodev alsa,id=audio0 \
    -device intel-hda \
    -device hda-micro,audiodev=audio0 \
    -device virtio-net,netdev=nic \
    -netdev "user,hostname=${HOSTNAME}-test,hostfwd=tcp::${SSH_PORT}-:22,id=nic" \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
    -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
    "${ISO_DRIVE[@]}" \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" \
    -monitor "unix:$MONITOR_SOCK,server,nowait" \
    -serial "unix:$SERIAL_SOCK,server,nowait" 2>/dev/null
