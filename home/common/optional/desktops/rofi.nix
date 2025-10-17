{
  pkgs,
  config,
  ...
}:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi; # rofi-wayland merged into rofi in unstable

    extraConfig = {
      show-icons = true;
      # icon-theme = "";
      # hover-select = true;
      drun-match-fields = "name";
      drun-display-format = "{name}";
      #FIXME not working
      drun-search-paths = "${config.home.homeDirectory}/.nix-profile/share/applciations,${config.home.homeDirectory}/.nix-profile/share/wayland-sessions";

    };
  };
}
