#!/usr/bin/env bash
# Test script for build failure and rollback functionality
# Usage: ./test-rollback.sh <vm-name>

set -euo pipefail

VM="${1:-sorrow}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

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

SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p $PORT"

echo "=== Testing Build Failure and Rollback on $VM ==="
echo

# Save current state
ORIGINAL_COMMIT=$(cd "$CONFIG_DIR" && jj log -r @ -T 'commit_id')
echo "📌 Original commit: $ORIGINAL_COMMIT"
echo

# Check VM's current commit
echo "📦 VM's current commit:"
VM_COMMIT=$($SSH "cd ~/nix-config && jj log -r @ -T 'commit_id' || git rev-parse HEAD")
echo "   $VM_COMMIT"
echo

# Step 1: Create a test commit with syntax error
echo "💥 Creating test commit with syntax error..."
echo

# Inject a syntax error
CONFIG_FILE="$CONFIG_DIR/hosts/$VM/default.nix"
if [ ! -f "$CONFIG_FILE" ]; then
	echo "❌ Config file not found: $CONFIG_FILE"
	exit 1
fi

# Add a syntax error (unclosed brace)
echo "  {{{ SYNTAX ERROR" >>"$CONFIG_FILE"

# Commit the broken config with jj
echo "📝 Committing broken config..."
(cd "$CONFIG_DIR" && jj describe -m "test: inject syntax error for rollback test")
BROKEN_COMMIT=$(cd "$CONFIG_DIR" && jj log -r @ -T 'commit_id')
echo "   Broken commit: $BROKEN_COMMIT"
echo

# Push to remote (VM will pull this)
echo "📤 Pushing broken config..."
(cd "$CONFIG_DIR" && jj git push)
echo

# Tell VM to pull the broken config
echo "🔄 Instructing VM to pull updates..."
$SSH "cd ~/nix-config && (jj git fetch && jj git export || git pull)"
echo

# Trigger upgrade (should fail and rollback)
echo "🚀 Triggering upgrade (expecting failure and rollback)..."
$SSH systemctl start nix-local-upgrade.service

# Wait for service to run
sleep 10

# Check if rollback occurred
echo
echo "🔍 Checking if rollback occurred..."
VM_AFTER=$($SSH "cd ~/nix-config && jj log -r @ -T 'commit_id' || git rev-parse HEAD")
echo "   VM commit after upgrade attempt: $VM_AFTER"
echo

if [ "$VM_AFTER" = "$VM_COMMIT" ]; then
	echo "✅ SUCCESS: VM rolled back to original commit"
	RESULT="PASS"
else
	echo "❌ FAILURE: VM did not rollback (expected $VM_COMMIT, got $VM_AFTER)"
	RESULT="FAIL"
fi
echo

# Check logs
echo "📋 Upgrade service logs (last 50 lines):"
$SSH journalctl -u nix-local-upgrade.service -n 50 --no-pager
echo

# Cleanup
echo "🧹 Cleaning up..."
# Abandon the test commit
(cd "$CONFIG_DIR" && jj abandon @)
# Restore the file using jj
(cd "$CONFIG_DIR" && jj restore "$CONFIG_FILE")

# Reset VM to current state
echo "🔄 Resetting VM to clean state..."
$SSH "cd ~/nix-config && (jj git fetch && jj git export || git pull)"
echo

echo "=== Test Complete ==="
echo "Result: $RESULT"
echo

if [ "$RESULT" = "PASS" ]; then
	exit 0
else
	exit 1
fi
