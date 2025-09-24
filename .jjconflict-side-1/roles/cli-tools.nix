# CLI tools rollup role (temporary consolidation)
{pkgs, ...}: {
  programs = {
    bat.enable = true;
    mosh.enable = true;
  };
  services.eternal-terminal.enable = true;

  environment.systemPackages = with pkgs; [
    # Input remapping
    kanata-with-cmd

    # Node.js
    nodejs

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

    # Compression
    p7zip

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

    # developer utilities
    delta
    eza
    fastfetch
    git-lfs
    gitFull
    kwalletcli
    moar
    tealdeer
    tmux-sessionizer
    tmuxp
    wezterm
    managarr

    skim
    antidote

    hyperfine

    asciinema_3

    qrencode
    fortune-kind
    glab
    # personal management
    khard
    khal
    vdirsyncer

    # pinentry variants
    pinentry-all
    pinentry-qt

    # Communication and news
    neomutt
    procmail
    newsboat
    weechat

    # desktop tool previously in desktop role
    python312Packages.samsungctl

    # CLI browsers kept here with mail/tui tools
    lynx
    w3m
  ];
}
