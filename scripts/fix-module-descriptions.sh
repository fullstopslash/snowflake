#!/usr/bin/env bash
# Fix module descriptions by converting them to comments
# This fixes the NixOS error: "Module has an unsupported attribute `description`"

set -euo pipefail

# List of all affected modules (from Explore agent analysis)
modules=(
  "modules/apps/ai/ai-tools.nix"
  "modules/apps/ai/crush.nix"
  "modules/apps/ai/voice-assistant.nix"
  "modules/apps/browsers/brave.nix"
  "modules/apps/browsers/chromium.nix"
  "modules/apps/browsers/firefox.nix"
  "modules/apps/browsers/ladybird.nix"
  "modules/apps/browsers/microsoft-edge.nix"
  "modules/apps/cli/comma.nix"
  "modules/apps/cli/shell.nix"
  "modules/apps/cli/tools-core.nix"
  "modules/apps/cli/tools-full.nix"
  "modules/apps/cli/zellij.nix"
  "modules/apps/comms/comms.nix"
  "modules/apps/desktop/creative.nix"
  "modules/apps/desktop/desktop.nix"
  "modules/apps/desktop/dunst.nix"
  "modules/apps/desktop/rofi.nix"
  "modules/apps/desktop/waybar.nix"
  "modules/apps/desktop/wayland.nix"
  "modules/apps/development/document-processing.nix"
  "modules/apps/development/latex.nix"
  "modules/apps/development/neovim.nix"
  "modules/apps/development/rust.nix"
  "modules/apps/development/tools.nix"
  "modules/apps/gaming/gaming.nix"
  "modules/apps/gaming/moondeck.nix"
  "modules/apps/media/media.nix"
  "modules/apps/media/obs.nix"
  "modules/apps/productivity/productivity.nix"
  "modules/apps/security/secrets.nix"
  "modules/apps/window-managers/hyprland.nix"
  "modules/apps/window-managers/niri.nix"
  "modules/apps/window-managers/plasma.nix"
  "modules/apps/xdg.nix"
  "modules/common/auto-upgrade.nix"
  "modules/common/golden-generation.nix"
  "modules/common/hardware.nix"
  "modules/common/nix-management.nix"
  "modules/common/sops-enforcement.nix"
  "modules/common/sops.nix"
  "modules/common/universal.nix"
  "modules/disks/bcachefs-disk.nix"
  "modules/disks/bcachefs-encrypt-disk.nix"
  "modules/disks/bcachefs-encrypt-impermanence-disk.nix"
  "modules/disks/bcachefs-impermanence-disk.nix"
  "modules/disks/bcachefs-luks-disk.nix"
  "modules/disks/bcachefs-luks-impermanence-disk.nix"
  "modules/disks/bcachefs-unlock.nix"
  "modules/disks/btrfs-disk.nix"
  "modules/disks/btrfs-impermanence-disk.nix"
  "modules/disks/btrfs-luks-impermanence-disk.nix"
  "modules/disks/default.nix"
  "modules/disks/luks-tpm-unlock.nix"
  "modules/disks/nvme.nix"
  "modules/hardware/gpu/hdr.nix"
  "modules/services/ai/ollama.nix"
  "modules/services/audio/easyeffects.nix"
  "modules/services/audio/pipewire.nix"
  "modules/services/audio/tools.nix"
  "modules/services/cli/atuin.nix"
  "modules/services/desktop/common.nix"
  "modules/services/development/containers.nix"
  "modules/services/development/quickemu.nix"
  "modules/services/display-manager/greetd.nix"
  "modules/services/display-manager/ly.nix"
  "modules/services/dotfiles/chezmoi-sync.nix"
  "modules/services/misc/flatpak.nix"
  "modules/services/networking/networking-base.nix"
  "modules/services/networking/openssh.nix"
  "modules/services/networking/sinkzone.nix"
  "modules/services/networking/ssh.nix"
  "modules/services/networking/ssh-no-sleep.nix"
  "modules/services/networking/syncthing.nix"
  "modules/services/networking/tailscale.nix"
  "modules/services/networking/tor.nix"
  "modules/services/networking/vpn.nix"
  "modules/services/networking/wireless.nix"
  "modules/services/security/bitwarden.nix"
  "modules/services/security/clamav.nix"
  "modules/services/security/yubikey.nix"
  "modules/services/storage/borg.nix"
  "modules/services/storage/network-storage.nix"
  "modules/theming/stylix.nix"
  "modules/users/minimal-user.nix"
  "modules/users/rain/nixos.nix"
  "modules/selection.nix"
)

cd /home/rain/nix-config

fixed=0
skipped=0
errors=0

for module in "${modules[@]}"; do
  if [ ! -f "$module" ]; then
    echo "⚠ Skipped: $module (file not found)"
    ((skipped++))
    continue
  fi

  # Extract the description text using sed
  description=$(sed -n 's/^[[:space:]]*description[[:space:]]*=[[:space:]]*"\(.*\)";[[:space:]]*$/\1/p' "$module" | head -1)

  if [ -z "$description" ]; then
    echo "⚠ Skipped: $module (no top-level description found)"
    ((skipped++))
    continue
  fi

  # Create a backup
  cp "$module" "$module.bak"

  # Replace the description line with a comment
  # This preserves the documentation while fixing the module error
  if sed -i "s|^[[:space:]]*description[[:space:]]*=[[:space:]]*\".*\";[[:space:]]*$|  # $description|" "$module"; then
    echo "✓ Fixed: $module"
    echo "  Description: $description"
    ((fixed++))
    rm "$module.bak"  # Remove backup on success
  else
    echo "✗ Error: $module"
    mv "$module.bak" "$module"  # Restore backup on error
    ((errors++))
  fi
done

echo ""
echo "Summary:"
echo "  Fixed: $fixed modules"
echo "  Skipped: $skipped modules"
echo "  Errors: $errors modules"
echo ""

if [ $fixed -gt 0 ]; then
  echo "✓ Successfully converted $fixed description attributes to comments"
  echo "  Documentation preserved, module errors fixed!"
fi
