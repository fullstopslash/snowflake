{ ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      scrollback-limit = 10000;
    };
  };
}
