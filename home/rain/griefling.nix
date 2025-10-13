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
          # Temporarily removed Hyprland to reduce memory usage for testing
          # "desktops/hyprland"
          
          "helper-scripts"
          "atuin.nix"
          "sops.nix"
        ])
    )
  );

  # Default monitor configuration for VM (only needed when Hyprland is enabled)
  # monitors = [
  #   {
  #     name = "Virtual-1";
  #     primary = true;
  #     width = 1920;
  #     height = 1080;
  #     refreshRate = 60;
  #     x = 0;
  #     y = 0;
  #     enabled = true;
  #   }
  # ];

  services.yubikey-touch-detector.enable = true;
}

