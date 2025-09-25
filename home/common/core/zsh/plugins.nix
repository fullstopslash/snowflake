{
  pkgs,
  lib,
}:
[
  {
    name = "powerlevel10k-config";
    src = ./p10k;
    file = "p10k.zsh.theme"; # NOTE: Don't use .zsh because of shfmt barfs on it, and can't ignore files
  }
  {
    name = "zsh-powerlevel10k";
    src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
    file = "powerlevel10k.zsh-theme";
  }
  {
    name = "zhooks";
    src = "${pkgs.zhooks}/share/zsh/zhooks";
  }
  {
    name = "you-should-use";
    src = "${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use";
  }
  # Allow zsh to be used in nix-shell
  {
    name = "zsh-nix-shell";
    file = "nix-shell.plugin.zsh";
    src = pkgs.fetchFromGitHub {
      owner = "chisui";
      repo = "zsh-nix-shell";
      rev = "v0.8.0";
      sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
    };
  }
]
#FIXME(iso): previous used the following line to avoid iso problems because iso doens't use overlays so we can't add custom packages.
# however, with plugins in a separate file we have issues access config
# move these to an optional custom plugins module and remove iso check
#++ lib.optionals (config.hostSpec.hostName != "iso" && pkgs ? "zsh-term-title") [
++ lib.optionals (pkgs ? "zsh-term-title") [
  {
    name = "zsh-term-title";
    src = "${pkgs.zsh-term-title}/share/zsh/zsh-term-title/";
  }
  {
    name = "cd-gitroot";
    src = "${pkgs.cd-gitroot}/share/zsh/cd-gitroot";
  }
  {
    name = "zsh-deep-autocd";
    src = "${pkgs.zsh-deep-autocd}/share/zsh/zsh-deep-autocd";
  }
  {
    name = "zsh-autols";
    src = "${pkgs.zsh-autols}/share/zsh/zsh-autols";
  }
]
