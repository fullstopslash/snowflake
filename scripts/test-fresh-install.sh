#!/usr/bin/env nix-shell
#!nix-shell --arg sandbox false -i bash -p qemu coreutils socat netcat
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
EXTRA_FILES=""
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
	--extra-files)
		EXTRA_FILES="$2"
		shift 2
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

	# Determine cache server IP (resolve waterbug.lan on the host)
	CACHE_HOST_IP=$(getent hosts waterbug.lan 2>/dev/null | awk '{ print $1 }' | head -1)
	CACHE_AVAILABLE=false
	SOCAT_PID=""

	if [[ -n $CACHE_HOST_IP ]]; then
		info "Resolved waterbug.lan -> $CACHE_HOST_IP"

		# Test if cache is actually reachable
		if timeout 5 nc -z -w 3 "$CACHE_HOST_IP" 9999 2>/dev/null; then
			info "Cache server is reachable at $CACHE_HOST_IP:9999"
			CACHE_AVAILABLE=true

			# Start transparent socat proxy: 10.0.2.2:9999 -> waterbug:9999
			# This allows VM to access cache via QEMU gateway IP
			info "Starting socat proxy for VM cache access (10.0.2.2:9999 -> $CACHE_HOST_IP:9999)..."
			socat TCP-LISTEN:9999,bind=localhost,reuseaddr,fork TCP:"$CACHE_HOST_IP":9999 &
			SOCAT_PID=$!

			# Ensure socat cleanup on exit
			trap "kill $SOCAT_PID 2>/dev/null || true" EXIT

			# Give socat a moment to start
			sleep 1

			# Verify socat is running
			if ! ps -p "$SOCAT_PID" >/dev/null 2>&1; then
				warn "Failed to start socat proxy, cache will not be available in VM"
				CACHE_AVAILABLE=false
			else
				success "socat proxy running (PID: $SOCAT_PID)"
			fi
		else
			warn "Cache server at $CACHE_HOST_IP:9999 is not reachable"
		fi
	else
		warn "Could not resolve waterbug.lan, cache will not be available"
	fi

	# Start VM headless for nixos-anywhere deployment
	# QEMU user-mode networking will NAT connections to external IPs automatically
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
		-netdev "user,hostname=${HOSTNAME}-fresh,hostfwd=tcp::2222-:2222,hostfwd=tcp::${SSH_PORT}-:22,restrict=off,id=nic" \
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

	# Create disko password file if DISKO_PASSWORD env var is set
	if [[ -n ${DISKO_PASSWORD:-} ]]; then
		info "Creating disko password file on installer..."
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
			-p "$SSH_PORT" root@127.0.0.1 \
			"echo '$DISKO_PASSWORD' > /tmp/disko-password && chmod 600 /tmp/disko-password"
	fi

	# Run nixos-anywhere
	echo ""
	printf '%s%s=== Running nixos-anywhere ===%s\n' "${BOLD}" "${GREEN}" "${NC}"
	echo ""
	info "Deploying $HOSTNAME configuration..."

	# Build nixos-anywhere command with optional --extra-files
	ANYWHERE_ARGS=(
		--flake ".#$HOSTNAME"
		-p "$SSH_PORT"
	)

	# Create temporary directory for extra files (cache resolver override)
	TEMP_EXTRA_FILES=$(mktemp -d)
	trap 'rm -rf "$TEMP_EXTRA_FILES"' EXIT

	# If cache is available via socat proxy, configure cache-resolver override
	# This tells cache-resolver to use 10.0.2.2 (QEMU gateway) instead of DNS lookup
	if [[ $CACHE_AVAILABLE == true ]]; then
		info "Creating cache-resolver override (10.0.2.2 for VM proxy access)..."
		mkdir -p "$TEMP_EXTRA_FILES/etc/cache-resolver"
		echo "10.0.2.2" > "$TEMP_EXTRA_FILES/etc/cache-resolver/waterbug-override"

		# Configure nix.conf for kexec installer to use Attic cache during build
		info "Creating nix.conf for kexec installer to use Attic cache..."
		mkdir -p "$TEMP_EXTRA_FILES/etc/nix"
		cat > "$TEMP_EXTRA_FILES/etc/nix/nix.conf" <<EOF
# Attic cache configuration for nixos-anywhere kexec environment
extra-substituters = http://10.0.2.2:9999/system
extra-trusted-public-keys = system:oio0pk/Mlb/DR3s1b78tHHmOclp82OkQrYOTRlaqays=
extra-trusted-substituters = http://10.0.2.2:9999/system
EOF
		success "Cache configured: kexec will use 10.0.2.2:9999 -> $CACHE_HOST_IP:9999"
	else
		info "Cache not available, no override needed (will use cache.nixos.org fallback)"
	fi

	# Merge user-provided extra-files with our temp directory
	if [[ -n $EXTRA_FILES ]]; then
		info "Merging user extra-files from: $EXTRA_FILES"
		cp -r "$EXTRA_FILES"/* "$TEMP_EXTRA_FILES/" 2>/dev/null || true
	fi

	# Use merged extra-files directory
	ANYWHERE_ARGS+=(--extra-files "$TEMP_EXTRA_FILES")

	# Deploy FULL config directly from main flake (not nixos-installer)
	cd "$REPO_ROOT"

	# Use custom phases if specified (e.g., skip reboot for TPM token generation)
	if [[ -n ${ANYWHERE_PHASES:-} ]]; then
		info "Using custom nixos-anywhere phases: $ANYWHERE_PHASES"
		ANYWHERE_ARGS+=(--phases "$ANYWHERE_PHASES")
	fi

	# Note: Cache configuration is now handled by:
	# 1. For installed system: cache-resolver service (uses override file above)
	# 2. For kexec installer: nix.conf in extra-files (created above)

	nix run github:nix-community/nixos-anywhere -- \
		"${ANYWHERE_ARGS[@]}" \
		root@127.0.0.1

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

# Determine cache server IP and start socat proxy if available
CACHE_HOST_IP=$(getent hosts waterbug.lan 2>/dev/null | awk '{ print $1 }' | head -1)
CACHE_AVAILABLE=false
SOCAT_PID=""

if [[ -n $CACHE_HOST_IP ]]; then
	info "Resolved waterbug.lan -> $CACHE_HOST_IP"

	# Test if cache is actually reachable
	if timeout 5 nc -z -w 3 "$CACHE_HOST_IP" 9999 2>/dev/null; then
		info "Cache server is reachable at $CACHE_HOST_IP:9999"
		CACHE_AVAILABLE=true

		# Start transparent socat proxy: 10.0.2.2:9999 -> waterbug:9999
		info "Starting socat proxy for VM cache access (10.0.2.2:9999 -> $CACHE_HOST_IP:9999)..."
		socat TCP-LISTEN:9999,bind=localhost,reuseaddr,fork TCP:"$CACHE_HOST_IP":9999 &
		SOCAT_PID=$!

		# Ensure socat cleanup on exit
		trap "kill $SOCAT_PID 2>/dev/null || true" EXIT

		# Give socat a moment to start
		sleep 1

		# Verify socat is running
		if ! ps -p "$SOCAT_PID" >/dev/null 2>&1; then
			warn "Failed to start socat proxy, cache will not be available in VM"
			CACHE_AVAILABLE=false
		else
			success "socat proxy running (PID: $SOCAT_PID)"
		fi
	else
		warn "Cache server at $CACHE_HOST_IP:9999 is not reachable"
	fi
else
	warn "Could not resolve waterbug.lan, cache will not be available"
fi

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
	-netdev "user,hostname=${HOSTNAME}-fresh,hostfwd=tcp::2222-:2222,hostfwd=tcp::${SSH_PORT}-:22,restrict=off,id=nic"
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

	info "Starting GUI VM with SPICE display..."

	# Start QEMU in background with SPICE
	qemu-system-x86_64 \
		"${QEMU_ARGS[@]}" \
		-vga qxl \
		-spice port=5930,disable-ticketing=on \
		-device virtio-serial-pci \
		-chardev spicevmc,id=spicechannel0,name=vdagent \
		-device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
		-device qemu-xhci,id=input \
		-device usb-kbd,bus=input.0 \
		-k en-us \
		-device usb-tablet,bus=input.0 \
		-audiodev spice,id=audio0 \
		-device intel-hda \
		-device hda-micro,audiodev=audio0 \
		-daemonize

	success "VM started (PID: $(cat "$PID_FILE"))"
	echo ""
	echo "  SSH: ssh -p $SSH_PORT root@127.0.0.1"
	echo "  Stop: ./scripts/stop-vm.sh $HOSTNAME"
	echo ""

	if [[ $CACHE_AVAILABLE == true ]]; then
		echo "  Cache: Available via proxy (socat PID: $SOCAT_PID)"
		echo "         VM will access cache at 10.0.2.2:9999 -> $CACHE_HOST_IP:9999"
	else
		echo "  Cache: Not available (will use cache.nixos.org fallback)"
	fi

	echo ""

	# Wait a moment for SPICE to be ready
	sleep 2

	# Auto-launch SPICE viewer
	info "Launching SPICE viewer..."
	exec spicy -h 127.0.0.1 -p 5930
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

	if [[ $CACHE_AVAILABLE == true ]]; then
		echo "  Cache: Available via proxy (socat PID: $SOCAT_PID)"
		echo "         VM will access cache at 10.0.2.2:9999 -> $CACHE_HOST_IP:9999"
	else
		echo "  Cache: Not available (will use cache.nixos.org fallback)"
	fi

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
