#!/usr/bin/env nix-shell
#!nix-shell -i bash -p qemu coreutils
# shellcheck shell=bash

# Test a fresh NixOS installation in a VM
#
# Usage: ./test-fresh-install.sh <hostname> [options]
#
# Options:
#   --gui              Run with display (default: headless)
#   --force            Skip confirmation prompt
#   --anywhere         Use nixos-anywhere instead of manual ISO install
#   --ssh-port PORT    SSH port for VM (default: 22222)
#   --memory GB        Memory in GB (default: 8)
#   --disk-size GB     Disk size in GB (default: 50)
#
# This script:
#   1. Stops any running VM for the host
#   2. Wipes disk image, UEFI vars, and sockets (fresh hardware)
#   3. Creates new disk image
#   4. Boots from ISO (or uses nixos-anywhere if --anywhere)
#   5. Provides SSH access for installation
#
# Examples:
#   ./test-fresh-install.sh griefling --gui
#   ./test-fresh-install.sh griefling --anywhere --force

set -eo pipefail

# -----------------------------------------------------------------------------
# Color helpers
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
die() {
	error "$1"
	exit 1
}

# -----------------------------------------------------------------------------
# Defaults
# -----------------------------------------------------------------------------
HOSTNAME=""
GUI=false
FORCE=false
USE_ANYWHERE=false
SSH_PORT=22222
MEMORY=8
DISK_SIZE=50

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_DIR="$REPO_ROOT/quickemu"

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
	case $1 in
	--gui)
		GUI=true
		shift
		;;
	--force | -f)
		FORCE=true
		shift
		;;
	--anywhere)
		USE_ANYWHERE=true
		shift
		;;
	--ssh-port)
		SSH_PORT="$2"
		shift 2
		;;
	--memory)
		MEMORY="$2"
		shift 2
		;;
	--disk-size)
		DISK_SIZE="$2"
		shift 2
		;;
	-h | --help)
		sed -n '3,/^$/p' "$0" | sed 's/^# \?//'
		exit 0
		;;
	-*)
		die "Unknown option: $1"
		;;
	*)
		# First non-option arg is hostname
		if [[ -z $HOSTNAME ]]; then
			HOSTNAME="$1"
		else
			die "Unexpected argument: $1"
		fi
		shift
		;;
	esac
done

[[ -z $HOSTNAME ]] && die "Usage: $0 <hostname> [options]"

# -----------------------------------------------------------------------------
# VM file paths
# -----------------------------------------------------------------------------
QCOW2="$VM_DIR/${HOSTNAME}-test.qcow2"
OVMF_VARS="$VM_DIR/${HOSTNAME}-OVMF_VARS.fd"
PID_FILE="$VM_DIR/${HOSTNAME}-test.pid"
MONITOR_SOCK="$VM_DIR/${HOSTNAME}-test-monitor.socket"
SERIAL_SOCK="$VM_DIR/${HOSTNAME}-test-serial.socket"

# -----------------------------------------------------------------------------
# Confirmation
# -----------------------------------------------------------------------------
if [[ $FORCE != true ]]; then
	echo ""
	printf '%s%s=== Fresh Install Test ===%s\n' "${BOLD}" "${YELLOW}" "${NC}"
	echo ""
	echo "This will WIPE all VM state for: $HOSTNAME"
	echo ""
	echo "Files to be deleted:"
	[[ -f $QCOW2 ]] && echo "  - $QCOW2 ($(du -h "$QCOW2" 2>/dev/null | cut -f1 || echo 'disk image'))"
	[[ -f $OVMF_VARS ]] && echo "  - $OVMF_VARS (UEFI variables)"
	[[ -S $MONITOR_SOCK ]] && echo "  - $MONITOR_SOCK (socket)"
	[[ -S $SERIAL_SOCK ]] && echo "  - $SERIAL_SOCK (socket)"
	[[ -f $PID_FILE ]] && echo "  - $PID_FILE (pid file)"
	echo ""
	echo "Mode: $(if $USE_ANYWHERE; then echo 'nixos-anywhere (automated)'; else echo 'ISO boot (manual install)'; fi)"
	echo "Display: $(if $GUI; then echo 'GUI'; else echo 'headless'; fi)"
	echo "SSH Port: $SSH_PORT"
	echo "Memory: ${MEMORY}GB"
	echo "Disk: ${DISK_SIZE}GB"
	echo ""
	read -p "Continue? [y/N] " -n 1 -r
	echo
	[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# -----------------------------------------------------------------------------
# Stop existing VM
# -----------------------------------------------------------------------------
if [[ -f $PID_FILE ]]; then
	PID=$(cat "$PID_FILE")
	if ps -p "$PID" >/dev/null 2>&1; then
		info "Stopping existing VM (PID: $PID)..."
		kill "$PID" 2>/dev/null || true
		sleep 2
		if ps -p "$PID" >/dev/null 2>&1; then
			warn "Force killing VM..."
			kill -9 "$PID" 2>/dev/null || true
		fi
		success "VM stopped"
	fi
fi

# -----------------------------------------------------------------------------
# Wipe VM state (fresh hardware simulation)
# -----------------------------------------------------------------------------
info "Wiping VM state for fresh install..."

mkdir -p "$VM_DIR"

# Remove disk image
if [[ -f $QCOW2 ]]; then
	rm -f "$QCOW2"
	success "Removed disk image"
fi

# Remove UEFI variables (resets boot order, secure boot state, etc.)
if [[ -f $OVMF_VARS ]]; then
	rm -f "$OVMF_VARS"
	success "Removed UEFI variables"
fi

# Remove stale sockets and pid file
rm -f "$PID_FILE" "$MONITOR_SOCK" "$SERIAL_SOCK" 2>/dev/null || true

# Clear SSH known hosts for the VM port (host key changes on fresh install)
ssh-keygen -R "[127.0.0.1]:${SSH_PORT}" 2>/dev/null || true
success "Cleared SSH known hosts for port ${SSH_PORT}"

# -----------------------------------------------------------------------------
# Create fresh disk image
# -----------------------------------------------------------------------------
info "Creating ${DISK_SIZE}GB disk image..."
qemu-img create -f qcow2 "$QCOW2" "${DISK_SIZE}G"
success "Disk image created: $QCOW2"

# -----------------------------------------------------------------------------
# Create fresh UEFI variables
# -----------------------------------------------------------------------------
info "Creating UEFI variables..."
OVMF_PATH=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link 2>/dev/null)
cp "$OVMF_PATH/FV/OVMF_VARS.fd" "$OVMF_VARS"
chmod u+w "$OVMF_VARS"
OVMF_CODE="$OVMF_PATH/FV/OVMF_CODE.fd"
success "UEFI variables created"

# -----------------------------------------------------------------------------
# Build ISO if needed (required for both manual and nixos-anywhere modes)
# -----------------------------------------------------------------------------
info "Checking for installer ISO..."
ISO_GLOB="$REPO_ROOT/result/iso/nixos-*.iso"

if ! compgen -G "$ISO_GLOB" >/dev/null 2>&1; then
	info "Building installer ISO (this may take a few minutes)..."
	(cd "$REPO_ROOT" && just iso)
fi

ISO_PATH=$(compgen -G "$ISO_GLOB" | head -1)
[[ -z $ISO_PATH ]] && die "No ISO found after build"
success "Using ISO: $(basename "$ISO_PATH")"

# -----------------------------------------------------------------------------
# nixos-anywhere mode
# -----------------------------------------------------------------------------
if [[ $USE_ANYWHERE == true ]]; then
	info "Starting VM for nixos-anywhere deployment..."

	# Verify host config exists before starting VM
	if ! nix eval ".#nixosConfigurations.$HOSTNAME" &>/dev/null; then
		die "Host '$HOSTNAME' not found in flake"
	fi

	# Start VM in background - boots from ISO first, then nixos-anywhere takes over
	qemu-system-x86_64 \
		-name "${HOSTNAME}-fresh-test" \
		-machine q35,smm=off,vmport=off,accel=kvm \
		-cpu host,topoext \
		-smp cores=2,threads=2,sockets=1 \
		-m "${MEMORY}G" \
		-pidfile "$PID_FILE" \
		-display none \
		-device virtio-rng-pci,rng=rng0 \
		-object rng-random,id=rng0,filename=/dev/urandom \
		-device virtio-net,netdev=nic \
		-netdev "user,hostname=${HOSTNAME}-fresh,hostfwd=tcp::${SSH_PORT}-:22,id=nic" \
		-drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
		-drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
		-drive "media=cdrom,index=0,file=$ISO_PATH" \
		-device virtio-blk-pci,drive=SystemDisk \
		-drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" \
		-monitor "unix:$MONITOR_SOCK,server,nowait" \
		-serial "unix:$SERIAL_SOCK,server,nowait" \
		-daemonize

	success "VM started (PID: $(cat "$PID_FILE"))"

	# Wait for SSH (ISO boots and SSH becomes available)
	info "Waiting for ISO to boot and SSH to become available..."
	SSH_READY=false
	for _ in {1..90}; do
		if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
			-p "$SSH_PORT" root@127.0.0.1 true 2>/dev/null; then
			SSH_READY=true
			success "SSH is ready"
			break
		fi
		sleep 2
		printf "."
	done
	echo ""

	if [[ $SSH_READY != true ]]; then
		die "SSH did not become available within 3 minutes. Check VM status."
	fi

	# Run nixos-anywhere
	echo ""
	printf '%s%s=== Running nixos-anywhere ===%s\n' "${BOLD}" "${GREEN}" "${NC}"
	echo ""
	info "Deploying $HOSTNAME configuration..."

	# Use nixos-installer flake which has minimal bootstrap configs with disko
	cd "$REPO_ROOT/nixos-installer"
	nix run github:nix-community/nixos-anywhere -- \
		--flake ".#$HOSTNAME" \
		-p "$SSH_PORT" \
		root@127.0.0.1
	cd "$REPO_ROOT"

	success "nixos-anywhere deployment complete!"
	echo ""
	echo "The VM should now be rebooting into the installed system."
	echo "Wait ~30s for reboot, then:"
	echo "  SSH: ssh -p $SSH_PORT root@127.0.0.1"
	echo "  Stop: ./scripts/stop-vm.sh $HOSTNAME"

	exit 0
fi

# -----------------------------------------------------------------------------
# ISO boot mode (manual install)
# -----------------------------------------------------------------------------
echo ""
printf '%s%s=== Starting Fresh Install VM ===%s\n' "${BOLD}" "${GREEN}" "${NC}"
echo ""
info "Booting from ISO for manual installation..."

# Common QEMU args
# shellcheck disable=SC2054  # Commas are QEMU option syntax, not array separators
QEMU_ARGS=(
	-name "${HOSTNAME}-fresh-test,process=${HOSTNAME}-fresh-test"
	-machine q35,smm=off,vmport=off,accel=kvm
	-global kvm-pit.lost_tick_policy=discard
	-cpu host,topoext
	-smp cores=2,threads=2,sockets=1
	-m "${MEMORY}G"
	-device virtio-balloon
	-pidfile "$PID_FILE"
	-rtc base=utc,clock=host
	-device virtio-rng-pci,rng=rng0
	-object rng-random,id=rng0,filename=/dev/urandom
	-device virtio-net,netdev=nic
	-netdev "user,hostname=${HOSTNAME}-fresh,hostfwd=tcp::${SSH_PORT}-:22,id=nic"
	-global driver=cfi.pflash01,property=secure,value=on
	-drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on"
	-drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS"
	-drive "media=cdrom,index=0,file=$ISO_PATH"
	-device virtio-blk-pci,drive=SystemDisk
	-drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2"
	-monitor "unix:$MONITOR_SOCK,server,nowait"
	-serial "unix:$SERIAL_SOCK,server,nowait"
)

if [[ $GUI == true ]]; then
	# Check for display
	if [[ -n $SSH_CLIENT ]] || [[ -n $SSH_TTY ]]; then
		die "GUI mode requires a local display. Remove --gui for headless mode."
	fi

	info "Starting GUI VM..."
	echo ""
	echo "  SSH: ssh -p $SSH_PORT root@127.0.0.1"
	echo "  Stop: Close window or ./scripts/stop-vm.sh $HOSTNAME"
	echo ""

	exec qemu-system-x86_64 \
		"${QEMU_ARGS[@]}" \
		-vga none \
		-device virtio-vga-gl,xres=1920,yres=1080 \
		-display sdl,gl=on \
		-device qemu-xhci,id=spicepass \
		-device usb-ehci,id=input \
		-device usb-kbd,bus=input.0 \
		-k en-us \
		-device usb-tablet,bus=input.0 \
		-audiodev alsa,id=audio0 \
		-device intel-hda \
		-device hda-micro,audiodev=audio0 \
		2>/dev/null
else
	# Headless mode
	qemu-system-x86_64 \
		"${QEMU_ARGS[@]}" \
		-display none \
		-daemonize

	success "VM started in background (PID: $(cat "$PID_FILE"))"
	echo ""
	echo "  SSH: ssh -p $SSH_PORT root@127.0.0.1"
	echo "  Stop: ./scripts/stop-vm.sh $HOSTNAME"
	echo ""
	echo "Once SSH is available, you can install NixOS:"
	echo "  1. Partition disk: sudo parted /dev/vda"
	echo "  2. Format: sudo mkfs.ext4 /dev/vda1"
	echo "  3. Mount: sudo mount /dev/vda1 /mnt"
	echo "  4. Install: sudo nixos-install --flake /path/to/config#$HOSTNAME"
	echo ""
	echo "Or use nixos-anywhere from your host:"
	echo "  nix run github:nix-community/nixos-anywhere -- --flake .#$HOSTNAME -p $SSH_PORT root@127.0.0.1"
fi
