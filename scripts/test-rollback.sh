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
ORIGINAL_COMMIT=$(git -C "$CONFIG_DIR" rev-parse HEAD)
echo "📌 Original commit: $ORIGINAL_COMMIT"
echo

# Check VM's current commit
echo "📦 VM's current commit:"
VM_COMMIT=$($SSH "cd ~/nix-config && git rev-parse HEAD")
echo "   $VM_COMMIT"
echo

# Step 1: Create a new branch for testing
BRANCH_NAME="test-rollback-$(date +%s)"
echo "🌿 Creating test branch: $BRANCH_NAME"
git -C "$CONFIG_DIR" checkout -b "$BRANCH_NAME"
echo

# Step 2: Inject a syntax error
echo "💥 Injecting syntax error into $VM config..."
CONFIG_FILE="$CONFIG_DIR/hosts/$VM/default.nix"
if [ ! -f "$CONFIG_FILE" ]; then
	echo "❌ Config file not found: $CONFIG_FILE"
	git -C "$CONFIG_DIR" checkout -
	git -C "$CONFIG_DIR" branch -D "$BRANCH_NAME"
	exit 1
fi

# Add a syntax error (unclosed brace)
echo "  {{{ SYNTAX ERROR" >>"$CONFIG_FILE"
echo

# Step 3: Commit the broken config
echo "📝 Committing broken config..."
git -C "$CONFIG_DIR" add "$CONFIG_FILE"
git -C "$CONFIG_DIR" commit -m "test: inject syntax error for rollback test"
BROKEN_COMMIT=$(git -C "$CONFIG_DIR" rev-parse HEAD)
echo "   Broken commit: $BROKEN_COMMIT"
echo

# Step 4: Push to remote (VM will pull this)
echo "📤 Pushing broken config..."
# Check if we're using jj or git
if [ -d "$CONFIG_DIR/.jj" ]; then
	echo "   Using jujutsu..."
	(cd "$CONFIG_DIR" && jj git import && jj git push)
else
	git -C "$CONFIG_DIR" push origin "$BRANCH_NAME"
fi
echo

# Step 5: Tell VM to pull the broken config
echo "🔄 Instructing VM to pull updates..."
$SSH "cd ~/nix-config && git fetch --all && git checkout $BRANCH_NAME && git pull origin $BRANCH_NAME"
echo

# Step 6: Trigger upgrade (should fail and rollback)
echo "🚀 Triggering upgrade (expecting failure and rollback)..."
$SSH systemctl start nix-local-upgrade.service

# Wait for service to run
sleep 10

# Step 7: Check if rollback occurred
echo
echo "🔍 Checking if rollback occurred..."
VM_AFTER=$($SSH "cd ~/nix-config && git rev-parse HEAD")
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

# Step 8: Check logs
echo "📋 Upgrade service logs (last 50 lines):"
$SSH journalctl -u nix-local-upgrade.service -n 50 --no-pager
echo

# Cleanup
echo "🧹 Cleaning up test branch..."
git -C "$CONFIG_DIR" checkout -
git -C "$CONFIG_DIR" branch -D "$BRANCH_NAME" || true

# Try to clean up remote branch if using git
if [ ! -d "$CONFIG_DIR/.jj" ]; then
	git -C "$CONFIG_DIR" push origin --delete "$BRANCH_NAME" 2>/dev/null || true
fi

# Reset VM to main branch
echo "🔄 Resetting VM to main branch..."
$SSH "cd ~/nix-config && git checkout dev && git pull origin dev"
echo

echo "=== Test Complete ==="
echo "Result: $RESULT"
echo

if [ "$RESULT" = "PASS" ]; then
	exit 0
else
	exit 1
fi
