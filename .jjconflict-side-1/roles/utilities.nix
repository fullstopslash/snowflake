# Utilities role
{pkgs, ...}: {
  # Utility packages

  programs.bat.enable = true;
  environment.systemPackages = with pkgs; [
    # Email and password management
    thunderbird
    keepassxc

    # Input remapping
    kanata-with-cmd

    # File management
    yazi
    chezmoi
    gnupg
    gopass
    ripgrep
    ripgrep-all
    bat-extras.batgrep
    bat

    # TUIs
    entr
    btop
    btop-rocm
    ncdu

    # Node.js
    nodejs

    # Compression
    p7zip

    # Wine with Wayland support
    wineWowPackages.waylandFull

    # System tools
    pv
    lsof
    fd
    age
    age-plugin-yubikey
    zstd
    jq
    yq-go
    rclone
    mkpasswd
    pwgen
  ];
}
