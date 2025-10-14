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
  
  # Terminal file manager
  programs.yazi.enable = true;
  
  # Disable home-manager config generation for files managed by chezmoi
  programs.kitty.enable = lib.mkForce false;
  programs.btop.enable = lib.mkForce false;
  programs.atuin.enable = lib.mkForce false;
  programs.zsh.enable = lib.mkForce false;  # Let chezmoi manage all zsh config
  # Keep SSH managed by home-manager - chezmoi config has compatibility issues
  
  # Hyprland already disabled via lib.mkIf false in default.nix
}

