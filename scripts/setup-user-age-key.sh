#!/usr/bin/env bash
# Setup per-host user age key for SOPS access
# Usage: setup-user-age-key.sh <HOST> <USER> <SSH_CONNECTION>
#
# This script:
# 1. Generates a unique age key for the user on the target host
# 2. Extracts the public key
# 3. Updates .sops.yaml with the per-host user key
# 4. Rekeys host-specific SOPS files
#
# Args:
#   HOST: Hostname (e.g., griefling, malphas)
#   USER: Username (e.g., rain)
#   SSH_CONNECTION: SSH connection string (e.g., "root@127.0.0.1 -p 22222")

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 <HOST> <USER> <SSH_CONNECTION>"
    exit 1
fi

HOST="$1"
USER="$2"
shift 2
SSH_CONN="$@"

echo "🔑 Setting up per-host user age key for $USER@$HOST..."

# Determine user home directory (check for /persist first)
USER_HOME=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONN \
    "if [ -d /persist ]; then echo /persist/home/$USER; else echo /home/$USER; fi")

echo "   User home: $USER_HOME"

# Generate age key on target host if it doesn't exist
echo "   Checking for existing age key..."
KEY_EXISTS=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONN \
    "test -f $USER_HOME/.config/sops/age/keys.txt && echo 'yes' || echo 'no'")

if [ "$KEY_EXISTS" = "no" ]; then
    echo "   Generating new age key on $HOST..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONN \
        "mkdir -p $USER_HOME/.config/sops/age && \
         nix-shell -p age --run 'age-keygen -o $USER_HOME/.config/sops/age/keys.txt' && \
         chmod 600 $USER_HOME/.config/sops/age/keys.txt && \
         chown -R $USER:users $USER_HOME/.config"
    echo "   ✅ Age key generated"
else
    echo "   ✅ Age key already exists"
fi

# Extract public key from target host
echo "   Extracting public key..."
USER_AGE_PUBKEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONN \
    "nix-shell -p age --run 'age-keygen -y $USER_HOME/.config/sops/age/keys.txt'")

echo "   Public key: $USER_AGE_PUBKEY"

# Update .sops.yaml with per-host user key
echo "   Updating .sops.yaml..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Add user key with format: rain_griefling
sops_update_age_key "users" "${USER}_${HOST}" "$USER_AGE_PUBKEY"

echo "✅ Per-host user age key setup complete for $USER@$HOST"
