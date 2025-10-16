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
ssh -p 22221 -i ~/.ssh/id_ed25519 rain@127.0.0.1 'bash -c "rm -f ~/.ssh/*.bk ~/.zshenv.bk ~/.config/hypr/*.bk ~/.config/atuin/*.bk ~/.config/btop/*.bk ~/.config/kitty/*.bk ~/.config/nvim/*.bk 2>/dev/null || true"'

echo "🔄 Rebuilding on griefling..."
# Rebuild (secrets are already updated via push)
ssh -p 22221 -i ~/.ssh/id_ed25519 rain@127.0.0.1 'cd /home/rain/src/nix/nix-config && nh os switch'

echo "✅ Done!"

