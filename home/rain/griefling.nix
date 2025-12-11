{ lib, pkgs, ... }:
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
          "desktops/hyprland/host-config-link.nix"
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

  # Install packages for programs whose config is managed by chezmoi
  # When programs.X.enable = false, the package isn't installed, so add them here
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

  # Enable atuin daemon for background sync (config is managed by chezmoi)
  systemd.user.sockets.atuin-daemon = lib.mkForce {
    Unit = {
      Description = "Atuin daemon socket";
    };
    Socket = {
      ListenStream = "%t/atuin.sock";
      SocketMode = "0600";
    };
    Install.WantedBy = [ "sockets.target" ];
  };

  systemd.user.services.atuin-daemon = lib.mkForce {
    Unit = {
      Description = "Atuin daemon for background sync";
      Requires = [ "atuin-daemon.socket" ];
      After = [ "atuin-daemon.socket" ];
    };
    Service = {
      ExecStart = "${pkgs.atuin}/bin/atuin daemon";
      Restart = "on-failure";
    };
  };

  # Disable ALL home-manager config generation - chezmoi manages dotfiles
  programs.kitty.enable = lib.mkForce false;
  programs.btop.enable = lib.mkForce false;
  # programs.atuin.enable = lib.mkForce false;  # Keep enabled for sync_address config
  programs.zsh.enable = lib.mkForce false;
  programs.bash.enable = lib.mkForce false;
  programs.git.enable = lib.mkForce false;
  programs.ssh.enable = lib.mkForce false;
  programs.direnv.enable = lib.mkForce false;

  # Enable Hyprland config generation for VM
  wayland.windowManager.hyprland.enable = lib.mkForce true;
}
