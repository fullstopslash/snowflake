#!/usr/bin/env bash
# Multi-VM Management Script
# Manages multiple test VMs (sorrow, torment, griefling) with unique port allocations
#
# Usage:
#   ./scripts/multi-vm.sh start sorrow      # Start sorrow VM
#   ./scripts/multi-vm.sh stop torment      # Stop torment VM
#   ./scripts/multi-vm.sh status            # Show all VM statuses
#   ./scripts/multi-vm.sh ssh sorrow        # SSH into sorrow
#   ./scripts/multi-vm.sh start-all         # Start all test VMs
#   ./scripts/multi-vm.sh stop-all          # Stop all test VMs

set -euo pipefail

# VM Port Allocations (to allow concurrent VMs)
declare -A VM_SSH_PORTS=(
	["griefling"]="22222"
	["sorrow"]="22223"
	["torment"]="22224"
)

declare -A VM_SPICE_PORTS=(
	["griefling"]="5930"
	["sorrow"]="5931"
	["torment"]="5932"
)

# VM Configuration
VM_MEMORY="${VM_MEMORY:-8}"
VM_DISK_SIZE="${VM_DISK_SIZE:-50}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
	echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
	echo -e "${GREEN}✅${NC} $1"
}

log_error() {
	echo -e "${RED}❌${NC} $1"
}

log_warn() {
	echo -e "${YELLOW}⚠${NC} $1"
}

get_vm_pid_file() {
	local vm="$1"
	echo "quickemu/${vm}.pid"
}

get_vm_disk_path() {
	local vm="$1"
	echo "quickemu/${vm}-test.qcow2"
}

is_vm_running() {
	local vm="$1"
	local pid_file
	pid_file=$(get_vm_pid_file "$vm")

	if [[ -f $pid_file ]]; then
		local pid
		pid=$(cat "$pid_file")
		if kill -0 "$pid" 2>/dev/null; then
			return 0
		else
			# Stale PID file
			rm -f "$pid_file"
			return 1
		fi
	fi
	return 1
}

start_vm() {
	local vm="$1"
	local ssh_port="${VM_SSH_PORTS[$vm]}"
	local spice_port="${VM_SPICE_PORTS[$vm]}"
	local disk_path
	local pid_file
	disk_path=$(get_vm_disk_path "$vm")
	pid_file=$(get_vm_pid_file "$vm")

	if ! [[ -f $disk_path ]]; then
		log_error "No disk image found for $vm. Run 'just vm-fresh $vm' first."
		return 1
	fi

	if is_vm_running "$vm"; then
		log_warn "$vm is already running (PID: $(cat "$pid_file"))"
		return 0
	fi

	log_info "Starting VM $vm (SSH: $ssh_port, SPICE: $spice_port)..."

	# Get OVMF paths
	OVMF_PATH=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link 2>/dev/null)
	OVMF_CODE="$OVMF_PATH/FV/OVMF_CODE.fd"
	OVMF_VARS="quickemu/${vm}-OVMF_VARS.fd"

	# Create OVMF_VARS if it doesn't exist
	if [[ ! -f $OVMF_VARS ]]; then
		cp "$OVMF_PATH/FV/OVMF_VARS.fd" "$OVMF_VARS"
	fi

	qemu-system-x86_64 \
		-machine q35,smm=off,vmport=off,accel=kvm \
		-enable-kvm \
		-cpu host \
		-m "${VM_MEMORY}G" \
		-smp 4,sockets=1,cores=4,threads=1 \
		-device virtio-balloon \
		-device virtio-rng-pci \
		-device intel-hda \
		-device hda-duplex \
		-drive "if=virtio,file=$disk_path,cache=writethrough,format=qcow2" \
		-netdev "user,hostname=$vm,hostfwd=tcp::${ssh_port}-:22,id=nic" \
		-device virtio-net-pci,netdev=nic \
		-drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
		-drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
		-display none \
		-daemonize \
		-pidfile "$pid_file" \
		&>/dev/null

	log_success "$vm started (headless)"
	log_info "  SSH: ssh -p $ssh_port root@127.0.0.1"
}

stop_vm() {
	local vm="$1"
	local pid_file
	pid_file=$(get_vm_pid_file "$vm")

	if ! is_vm_running "$vm"; then
		log_warn "$vm is not running"
		return 0
	fi

	local pid
	pid=$(cat "$pid_file")
	log_info "Stopping VM $vm (PID: $pid)..."

	kill "$pid" 2>/dev/null || true
	sleep 2

	if kill -0 "$pid" 2>/dev/null; then
		log_warn "VM didn't stop gracefully, forcing..."
		kill -9 "$pid" 2>/dev/null || true
	fi

	rm -f "$pid_file"
	log_success "$vm stopped"
}

ssh_vm() {
	local vm="$1"
	local ssh_port="${VM_SSH_PORTS[$vm]}"

	if ! is_vm_running "$vm"; then
		log_error "$vm is not running. Start it with: ./scripts/multi-vm.sh start $vm"
		return 1
	fi

	log_info "Connecting to $vm on port $ssh_port..."
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$ssh_port" root@127.0.0.1
}

show_status() {
	echo "VM Status:"
	echo "========================================="

	for vm in "${!VM_SSH_PORTS[@]}"; do
		local ssh_port="${VM_SSH_PORTS[$vm]}"
		local disk_path
		disk_path=$(get_vm_disk_path "$vm")

		if is_vm_running "$vm"; then
			local pid
			local pid_file
			pid_file=$(get_vm_pid_file "$vm")
			pid=$(cat "$pid_file")
			echo -e "${GREEN}✅ $vm${NC} (PID: $pid)"
			echo "   SSH: ssh -p $ssh_port root@127.0.0.1"
		elif [[ -f $disk_path ]]; then
			echo -e "${YELLOW}⏸ $vm${NC} (stopped, disk exists)"
			echo "   Start: ./scripts/multi-vm.sh start $vm"
		else
			echo -e "${RED}❌ $vm${NC} (no disk image)"
			echo "   Create: just vm-fresh $vm"
		fi
	done
}

start_all() {
	log_info "Starting all test VMs..."
	for vm in "${!VM_SSH_PORTS[@]}"; do
		start_vm "$vm" || true
	done
	echo
	show_status
}

stop_all() {
	log_info "Stopping all test VMs..."
	for vm in "${!VM_SSH_PORTS[@]}"; do
		stop_vm "$vm" || true
	done
}

# Main command dispatcher
COMMAND="${1:-help}"
VM="${2:-}"

case "$COMMAND" in
start)
	if [[ -z $VM ]]; then
		log_error "Usage: $0 start <vm-name>"
		exit 1
	fi
	if [[ ! -v "VM_SSH_PORTS[$VM]" ]]; then
		log_error "Unknown VM: $VM (known: ${!VM_SSH_PORTS[*]})"
		exit 1
	fi
	start_vm "$VM"
	;;
stop)
	if [[ -z $VM ]]; then
		log_error "Usage: $0 stop <vm-name>"
		exit 1
	fi
	if [[ ! -v "VM_SSH_PORTS[$VM]" ]]; then
		log_error "Unknown VM: $VM (known: ${!VM_SSH_PORTS[*]})"
		exit 1
	fi
	stop_vm "$VM"
	;;
ssh)
	if [[ -z $VM ]]; then
		log_error "Usage: $0 ssh <vm-name>"
		exit 1
	fi
	if [[ ! -v "VM_SSH_PORTS[$VM]" ]]; then
		log_error "Unknown VM: $VM (known: ${!VM_SSH_PORTS[*]})"
		exit 1
	fi
	ssh_vm "$VM"
	;;
status)
	show_status
	;;
start-all)
	start_all
	;;
stop-all)
	stop_all
	;;
help | --help | -h)
	echo "Multi-VM Management Script"
	echo
	echo "Usage: $0 <command> [vm-name]"
	echo
	echo "Commands:"
	echo "  start <vm>      Start a VM (sorrow, torment, griefling)"
	echo "  stop <vm>       Stop a VM"
	echo "  ssh <vm>        SSH into a VM"
	echo "  status          Show status of all VMs"
	echo "  start-all       Start all test VMs"
	echo "  stop-all        Stop all test VMs"
	echo "  help            Show this help"
	echo
	echo "Known VMs:"
	for vm in "${!VM_SSH_PORTS[@]}"; do
		echo "  - $vm (SSH: ${VM_SSH_PORTS[$vm]})"
	done
	;;
*)
	log_error "Unknown command: $COMMAND"
	echo "Run '$0 help' for usage information"
	exit 1
	;;
esac
