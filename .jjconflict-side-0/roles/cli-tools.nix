# CLI tools rollup role (temporary consolidation)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
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
  programs = {
    mosh.enable = true;
  };
  services.eternal-terminal.enable = true;
}
