{ inputs, pkgs, ... }:
{
  # host-wide styling
  #TODO(stylix): define themes per host via hostSpec

  stylix = {
    enable = true;
    autoEnable = true;
    image = "${inputs.nix-assets}/images/wallpapers/zen-01.png";

    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    #FIXME(stylix): finalize custom colours and upstream to https://github.com/tinted-theming/schemes
    override = {
      scheme = "ascendancy";
      author = "emergentmind";
      #base00 = "#282828"; # ----      background
      base00 = "#282828"; # ----      background
      #base01 = "#32302f"; # ---       lighter background status bar
      base01 = "#212f3d"; # ---       lighter background status bar
      #base02 = "#504945"; # --        selection background
      base02 = "#32302f"; # --        selection background
      #base03 = "#665c54"; # -         Comments, Invisibles, Line highlighting
      base03 = "#504945"; # -         Comments, Invisibles, Line highlighting
      #base04 = "#bdae93"; # +         dark foreground status bar
      base04 = "#665c54"; # +         dark foreground status bar
      #base05 = "#d5c7a1"; # ++        foreground, caret, delimiters, operators
      base05 = "#bdae93"; # ++        foreground, caret, delimiters, operators
      #base05 = "#B59B4D"; # ++        foreground, caret, delimiters, operators
      #base06 = "#ebdbb2"; # +++       light foreground, rarely used
      base06 = "#d5c7a1"; # +++       light foreground, rarely used
      #base07 = "#fbf1c7"; # ++++      lightest foreground, rarely used
      base07 = "#ebdbb2"; # ++++      lightest foreground, rarely used
      base08 = "#fb4934"; # red       vars, xml tags, markup link text, markup lists, diff deleted
      base09 = "#fe8019"; # orange    Integers, Boolean, Constants, XML Attributes, Markup Link Url
      base0A = "#fabd2f"; # yellow    Classes, Markup Bold, Search Text Background
      base0B = "#b8bb26"; # green     Strings, Inherited Class, Markup Code, Diff Inserted
      base0C = "#8ec07c"; # cyan      Support, Regular Expressions, Escape Characters, Markup Quotes
      base0D = "#458588"; # blue      Functions, Methods, Attribute IDs, Headings
      #base0E = "#8f3f71"; # purple    Keywords, Storage, Selector, Markup Italic, Diff Changed
      #base0E = "#ff9400"; # purple    Keywords, Storage, Selector, Markup Italic, Diff Changed
      base0E = "#ffb900"; # purple    Keywords, Storage, Selector, Markup Italic, Diff Changed

      base0F = "#c66e02"; # darkred   Deprecated Highlighting for Methods and Functions, Opening/Closing Embedded Language Tags

    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";

    #cursor = {
    #        package = pkgs.foo;
    #        name = "";
    #      };

    fonts = rec {
      monospace = {
        package = pkgs.unstable.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sansSerif = monospace;
      serif = monospace;
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        #        applications https://github.com/tinted-theming/schemes= 12;
        terminal = 12;
        desktop = 12;
        popups = 10;
      };
    };
    # program specific exclusions
    #targets.foo = {
    #  enable = true;
    #  property = bar;
    #};

  };
}
