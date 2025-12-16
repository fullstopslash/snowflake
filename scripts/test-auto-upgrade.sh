#!/usr/bin/env bash
# Test script for auto-upgrade functionality
# Usage: ./test-auto-upgrade.sh <vm-name>

set -euo pipefail

VM="${1:-sorrow}"
SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost"

# Detect SSH port for VM
case "$VM" in
griefling)
	PORT=2222
	;;
sorrow)
	PORT=2223
	;;
torment)
	PORT=2224
	;;
*)
	echo "Unknown VM: $VM"
	exit 1
	;;
esac

SSH="$SSH_CMD -p $PORT"

echo "=== Testing Auto-Upgrade on $VM ==="
echo

# Test 1: Check current generation
echo "📋 Current system generation:"
$SSH nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -n 5
echo

# Test 2: Check upgrade service status
echo "🔍 Auto-upgrade service status:"
$SSH systemctl status nix-local-upgrade.service --no-pager || true
echo

# Test 3: Check upgrade timer
echo "⏰ Upgrade timer status:"
$SSH systemctl list-timers nix-local-upgrade.timer --no-pager
echo

# Test 4: Check current git commit
echo "📦 Current nix-config commit:"
$SSH "cd ~/nix-config && git log -1 --oneline"
echo

# Test 5: Trigger manual upgrade
echo "🚀 Triggering manual upgrade..."
$SSH systemctl start nix-local-upgrade.service

# Wait a bit for service to start
sleep 5

# Test 6: Monitor upgrade progress
echo "📡 Monitoring upgrade (Ctrl+C to stop):"
echo "   (This will stream logs until upgrade completes)"
echo
$SSH journalctl -fu nix-local-upgrade.service

echo
echo "✅ Test completed"
