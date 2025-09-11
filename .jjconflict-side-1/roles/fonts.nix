# Fonts configuration
{pkgs, ...}: {
  # Fonts
  fonts.packages = with pkgs; [
    xkcd-font
    nerd-fonts.symbols-only
    victor-mono
    nerd-fonts.victor-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    departure-mono
    nerd-fonts.departure-mono
    nerd-fonts.comic-shanns-mono
    nerd-fonts.inconsolata
    iosevka
    nerd-fonts.iosevka
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk-sans
    liberation_ttf
    fira
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    cozette
    proggyfonts
    # Keep both variants for Victor and Departure per user preference
    # Inter nerdfont moved from desktop role
    inter-nerdfont
    # A Shavian, alternative english font
    inter-alia
  ];
}
