#!/usr/bin/env bash
# Automated test script for remote disk unlocking via initrd SSH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${1:-anguish}"
INITRD_PORT=2222
MAIN_PORT=22225

echo "🧪 Testing remote unlock for $HOST..."

# Step 1: Retrieve SOPS-encrypted test SSH key
echo "📥 Retrieving test SSH key from SOPS..."
TEST_KEY_DIR=$(mktemp -d)
trap "rm -rf '$TEST_KEY_DIR'" EXIT

cd ../nix-secrets
sops --decrypt sops/test-keys.yaml | \
    yq eval '.initrd_unlock_key' - > "$TEST_KEY_DIR/test_key"
chmod 600 "$TEST_KEY_DIR/test_key"

echo "✅ Test key retrieved and saved to temp location"

# Step 2: Wait for initrd SSH to be available
echo "⏳ Waiting for initrd SSH on port $INITRD_PORT..."
timeout 60 bash -c "while ! nc -z 127.0.0.1 $INITRD_PORT; do sleep 1; done" || {
    echo "❌ Initrd SSH never became available"
    exit 1
}
echo "✅ Initrd SSH is listening"

# Step 3: Get initrd SSH fingerprint
echo "🔍 Getting initrd SSH host key fingerprint..."
INITRD_FP=$(ssh-keyscan -p $INITRD_PORT 127.0.0.1 2>/dev/null | ssh-keygen -lf - 2>&1 || echo "FAILED")
echo "   Initrd fingerprint: $INITRD_FP"

# Step 4: Test SSH connection to initrd
echo "🔐 Testing SSH connection to initrd..."
if ssh -i "$TEST_KEY_DIR/test_key" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    -p $INITRD_PORT \
    root@127.0.0.1 \
    'echo "✅ SSH connection successful!"' 2>&1; then
    echo "✅ Initrd SSH authentication works!"
else
    echo "❌ SSH connection failed"
    echo "   This could mean:"
    echo "   - Test key not in authorized_keys"
    echo "   - sshd configuration issue"
    echo "   - Host key problem"
    exit 1
fi

# Step 5: Note about unlock
echo ""
echo "📝 Manual unlock required:"
echo "   The system is waiting for disk password."
echo "   To unlock, run:"
echo "   ssh -i $TEST_KEY_DIR/test_key -p $INITRD_PORT root@127.0.0.1"
echo "   Then enter the disk password when prompted."
echo ""
echo "   Or unlock manually via console and press Enter to continue..."
read -p "Press Enter after unlocking the disk..."

# Step 6: Wait for main SSH
echo "⏳ Waiting for main SSH on port $MAIN_PORT..."
timeout 60 bash -c "while ! nc -z 127.0.0.1 $MAIN_PORT; do sleep 1; done" || {
    echo "❌ Main SSH never became available"
    exit 1
}
echo "✅ Main SSH is listening"

# Step 7: Get main SSH fingerprint
echo "🔍 Getting main SSH host key fingerprint..."
MAIN_FP=$(ssh-keyscan -p $MAIN_PORT 127.0.0.1 2>/dev/null | ssh-keygen -lf - 2>&1 || echo "FAILED")
echo "   Main system fingerprint: $MAIN_FP"

# Step 8: Compare fingerprints
echo ""
echo "🔎 Fingerprint comparison:"
echo "   Initrd:  $INITRD_FP"
echo "   Main:    $MAIN_FP"
echo ""

if [ "$INITRD_FP" = "$MAIN_FP" ] && [ "$INITRD_FP" != "FAILED" ]; then
    echo "✅ SUCCESS! Fingerprints match - same SSH key used for both!"
else
    echo "❌ FAILED! Fingerprints don't match or couldn't be retrieved"
    exit 1
fi

# Step 9: Verify deployment
echo "🔍 Verifying key deployment on booted system..."
ssh -i "$TEST_KEY_DIR/test_key" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -p $MAIN_PORT \
    rain@127.0.0.1 \
    'sudo ls -la /persist/etc/ssh/ssh_host_ed25519_key* && \
     sudo ssh-keygen -lf /persist/etc/ssh/ssh_host_ed25519_key.pub'

echo ""
echo "🎉 All tests passed!"
echo "   ✅ Initrd SSH works"
echo "   ✅ Main SSH works"
echo "   ✅ Same fingerprint for both"
echo "   ✅ Key deployed to /persist"
