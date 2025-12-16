# CLI tools rollup role (temporary consolidation)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.cli.tools;
in
{
  options.myModules.apps.cli.tools = {
    enable = lib.mkEnableOption "Extended CLI tools";
  };

  config = lib.mkIf cfg.enable {
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

      # Core utilities
      coreutils
      findutils
      curl
      wget
      tree

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

      dust # disk usage analyzer
      imagemagick

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
      zip
      unzip
      unrar

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
      pciutils
      usbutils
      nix-tree # nix package tree viewer
      xdg-utils
      xdg-user-dirs

      # Debugging and system analysis
      e2fsprogs # lsattr, chattr
      cntr # nixpkgs sandbox debugging
      strace
      socat # networking utility, serial console forwarding

      # System info
      pfetch
      neofetch

      cliphist

      # Build tools
      cmake
      pre-commit

      # Python
      (python3.withPackages (
        ps: with ps; [
          pip
          virtualenv
        ]
      ))
      uv # Modern Python package installer

      # developer utilities
      difftastic
      delta
      eza
      fastfetch
      git-lfs
      gitFull
      jujutsu # version control system
      tokei # code statistics
      zola # static site generator
      kwalletcli
      # moor # FIXME: Not in nixpkgs
      tmux-sessionizer
      tmuxp
      sesh
      wezterm
      urlencode
      managarr
      websocat

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
      procmail
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
  };
}
