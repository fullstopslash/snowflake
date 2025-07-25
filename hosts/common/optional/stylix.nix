{ lib, pkgs, ... }:
{
  # host-wide styling
  #TODO(stylix): define themes per host via hostSpec
  stylix = {
    enable = true;
    autoEnable = true;
    image = (lib.custom.relativeToRoot "assets/wallpapers/zen-01.png");
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-medium.yaml";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    #cursor = {
    #        package = pkgs.foo;
    #        name = "";
    #      };
    #     fonts = {
    #monospace = {
    #    package = pkgs.foo;
    #    name = "";
    #};
    #sanSerif = {
    #    package = pkgs.foo;
    #    name = "";
    #};
    #serif = {
    #    package = pkgs.foo;
    #    name = "";
    #};
    #    sizes = {
    #        applications = 12;
    #        terminal = 12;
    #        desktop = 12;
    #        popups = 10;
    #    };
    #};
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";

    # program specific exclusions
    #targets.foo = {
    #  enable = true;
    #  property = bar;
    #};

  };
}
