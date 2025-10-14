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
          # "desktops/hyprland/rain-custom.nix"  # Disabled - using chezmoi for dotfiles
          "desktops/waybar.nix"
          "desktops/rofi.nix"
          
          "helper-scripts"
          "chezmoi.nix"
          "atuin.nix"
          "sops.nix"
        ])
    )
  );

  # Default monitor configuration for VM
  monitors = [
    {
      name = "Virtual-1";
      primary = true;
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 0;
      y = 0;
      enabled = true;
    }
  ];

  # Yubikey disabled for test VM (useYubikey = false in host config)
  # services.yubikey-touch-detector.enable = false;
}

