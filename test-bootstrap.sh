#!/usr/bin/env bash
# Test script for bootstrap-nixos.sh with local VM
set -euo pipefail

echo "=== Bootstrap Test Script ==="
echo ""
echo "This will test the fixed bootstrap script against your test VM"
echo ""

# Check if VM is running
if ! pgrep -f "qemu.*nixos-test" >/dev/null; then
    echo "❌ Test VM is not running"
    echo ""
    echo "To start the VM, run:"
    echo "  ./nixos-test.sh"
    echo ""
    echo "Then wait for it to boot into the ISO (you'll see a login prompt)"
    echo "and run this script again."
    exit 1
else
    echo "✅ Test VM is running"
fi

# Test SSH connectivity
echo ""
echo "Testing SSH connectivity to VM..."
echo "The ISO uses user 'fullstopslash' (or 'nixos' fallback)"
echo ""

# Try connecting as different users to see what works (using 127.0.0.1 to avoid IPv6 issues)
for user in ta nixos; do
    echo "Trying user: $user"
    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o BatchMode=yes -p 22220 -i ~/.ssh/id_ed25519 \
        ${user}@127.0.0.1 "echo 'Connected as $user'" 2>/dev/null; then
        WORKING_USER=$user
        echo "✅ SSH connection successful as '$user'!"
        break
    fi
done

if [ -z "${WORKING_USER:-}" ]; then
    echo "❌ Could not connect to VM via SSH"
    echo ""
    echo "The ISO might not have your SSH key authorized."
    echo "You can either:"
    echo "  1. Set a password on the ISO and use password auth"
    echo "  2. Manually authorize your key on the ISO"
    echo ""
    echo "To check manually, try:"
    echo "  ssh -p 22220 ta@127.0.0.1"
    echo ""
    exit 1
fi

echo ""
echo "✅ VM is ready for bootstrap testing!"
echo ""
echo "NOTE: The test will use 'guppy' as the test hostname."
echo "This will:"
echo "  1. Run nixos-anywhere (wipe the test VM disk)"
echo "  2. Test the age-key generation with the new wait logic"
echo ""
echo "Bootstrap command that will run:"
echo ""
echo "  ./scripts/bootstrap-nixos.sh \\"
echo "    -n guppy \\"
echo "    -d 127.0.0.1 \\"
echo "    -u ${WORKING_USER} \\"
echo "    -k ~/.ssh/id_ed25519 \\"
echo "    --port 22220 \\"
echo "    --debug"
echo ""
echo "Press Enter to continue, or Ctrl+C to cancel..."
read -r

cd "$(dirname "$0")"

# Run the bootstrap script (using 127.0.0.1 to avoid localhost IPv6 resolution issues)
./scripts/bootstrap-nixos.sh \
    -n guppy \
    -d 127.0.0.1 \
    -u "${WORKING_USER}" \
    -k ~/.ssh/id_ed25519 \
    --port 22220 \
    --debug

echo ""
echo "✅ Test completed!"
