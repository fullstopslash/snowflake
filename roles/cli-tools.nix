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
    # bat-extras.batgrep
    bat
    trash-cli

    # Tools for parallelization
    parallel
    pueue
    nq
    moreutils

    # TUIs
    browsh
    entr
    btop
    btop-rocm
    ncdu
    grex
    python313Packages.faker
    ttyd
    viddy
    sampler

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
    jaq
    bc
    tomlq
    toml-cli
    dasel
    yq-go
    rclone
    mkpasswd
    pwgen

    cliphist
    # developer utilities
    difftastic
    delta
    eza
    fastfetch
    git-lfs
    gitFull
    kwalletcli
    moor
    tmux-sessionizer
    tmuxp
    wezterm
    urlencode
    managarr
    websocat
    gum
    postgresql
    hexyl

    cowsay
    kittysay
    # fancy-cat
    lolcat
    fortune
    charasay
    pokemonsay

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
    sqlite
    exiftool
    exiv2

    # pinentry variants
    pinentry-all
    pinentry-qt

    # Communication and news
    neomutt
    # procmail  # Fails to build with modern GCC
    newsboat
    weechat

    aspell
    aspellDicts.en
    aspellDicts.fr
    aspellDicts.es

    # desktop tool previously in desktop role
    python312Packages.samsungctl

    # CLI browsers kept here with mail/tui tools
    lynx
    w3m
  ];
}
