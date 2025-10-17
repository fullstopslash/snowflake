#!/usr/bin/env bash
# Push changes to griefling VM and rebuild

set -e

cd "$(dirname "$0")/.."

echo "📤 Pushing nix-config to griefling..."
GIT_SSH_COMMAND="ssh -p 22221 -i ~/.ssh/id_ed25519" git push griefling dev

echo "📤 Pushing nix-secrets to griefling..."
cd ../nix-secrets
GIT_SSH_COMMAND="ssh -p 22221 -i ~/.ssh/id_ed25519" git push griefling simple
cd ../nix-config

echo "🧹 Cleaning up backup files..."
GRIEFLING_USER="${GRIEFLING_USER:-$USER}"
ssh -p 22221 -i ~/.ssh/id_ed25519 ${GRIEFLING_USER}@127.0.0.1 'bash -c "rm -f ~/.ssh/*.bk ~/.zshenv.bk ~/.config/hypr/*.bk ~/.config/atuin/*.bk ~/.config/btop/*.bk ~/.config/kitty/*.bk ~/.config/nvim/*.bk 2>/dev/null || true"'

echo "🔄 Rebuilding on griefling..."
# Rebuild (secrets are already updated via push)
ssh -p 22221 -i ~/.ssh/id_ed25519 ${GRIEFLING_USER}@127.0.0.1 'cd ~/src/nix/nix-config && nh os switch'

echo "✅ Done!"

