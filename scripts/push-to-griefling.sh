#!/usr/bin/env bash
# Push changes to griefling VM and rebuild

set -e

cd "$(dirname "$0")/.."

echo "📤 Pushing to griefling..."
GIT_SSH_COMMAND="ssh -p 22221 -i ~/.ssh/id_ed25519" git push griefling dev

echo "🔄 Rebuilding on griefling..."
ssh -p 22221 -i ~/.ssh/id_ed25519 rain@127.0.0.1 'cd /home/rain/src/nix/nix-config && sudo nixos-rebuild switch --flake .#griefling'

echo "✅ Done!"

