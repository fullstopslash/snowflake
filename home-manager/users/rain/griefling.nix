# Griefling VM - Home Manager config for rain user
#
# Hyprland settings are in raw config files, not Nix:
#   - home-manager/common/optional/desktops/hyprland/host-configs/common.conf
#   - home-manager/common/optional/desktops/hyprland/host-configs/griefling.conf
{ lib, pkgs, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      [
        #
        # ========== Required Configs ==========
        #
        "home-manager/common/core"
        "home-manager/common/core/nixos.nix"

        "home-manager/users/rain/common/nixos.nix"
      ]
      ++
        #
        # ========== Host-specific Optional Configs ==========
        #
        (map (f: "home-manager/common/optional/${f}") [
          "desktops/hyprland"
          "desktops/hyprland/host-config-link.nix"
          "desktops/waybar.nix"
          "desktops/rofi.nix"

          "helper-scripts"
          "chezmoi.nix"
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

  # Terminal file manager
  programs.yazi.enable = true;

  # Install packages for programs whose config is managed by chezmoi
  home.packages = with pkgs; [
    atuin
    kitty
    ghostty
    firefox
    xfce.thunar
    wlogout
    rofi
    wofi
    btop
  ];

  # Disable HM config generation - chezmoi manages dotfiles
  programs.kitty.enable = lib.mkForce false;
  programs.btop.enable = lib.mkForce false;
  programs.zsh.enable = lib.mkForce false;
  programs.bash.enable = lib.mkForce false;
  programs.git.enable = lib.mkForce false;
  programs.ssh.enable = lib.mkForce false;
  programs.direnv.enable = lib.mkForce false;
}
