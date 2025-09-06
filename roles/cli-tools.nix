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

    qrencode
    fortune-kind
    # personal management
    khard
    stable.khal
    stable.vdirsyncer

    # pinentry variants
    pinentry-all
    pinentry-qt

    # desktop tool previously in desktop role
    python312Packages.samsungctl

    # CLI browsers kept here with mail/tui tools
    lynx
    w3m
  ];
}
