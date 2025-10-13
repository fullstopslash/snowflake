{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      [
        #
        # ========== Required Configs ==========
        #
        "home/common/core"
        "home/common/core/nixos.nix"

        "home/rain/common/nixos.nix"
      ]
      ++
        #
        # ========== Host-specific Optional Configs ==========
        #
        (map (f: "home/common/optional/${f}") [
          "desktops/hyprland"
          "desktops/waybar.nix"
          "desktops/rofi.nix"
          "desktops/gtk.nix"
          "desktops/services/dunst.nix"
          
          "helper-scripts"
          "atuin.nix"
          "sops.nix"
          
          "browsers/firefox.nix"
        ])
    )
  );

  services.yubikey-touch-detector.enable = true;
}

