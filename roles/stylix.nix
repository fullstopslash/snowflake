{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.stylix;
  inherit (lib) mkEnableOption mkOption types mkIf;
in {
  options.roles.stylix = {
    enable = mkEnableOption "stylix theming system";

    theme = mkOption {
      type = types.enum [
        "catppuccin-mocha"
        "catppuccin-latte"
        "dracula"
        "nord"
        "gruvbox-dark"
        "custom"
      ];
      default = "catppuccin-mocha";
      description = "Theme preset to use";
    };

    wallpaper = mkOption {
      type = types.path;
      description = "Path to wallpaper image";
      example = ./wallpapers/my-wallpaper.jpg;
    };

    base16Scheme = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Custom base16 scheme file";
    };

    cursorTheme = mkOption {
      type = types.enum [
        "Bibata-Modern-Classic"
        "Bibata-Modern-Ice"
        "Bibata-Modern-Amber"
        "Capitaine"
        "Volantes_Cursor"
        "Catppuccin-Mocha"
        "Catppuccin-Macchiato"
        "Catppuccin-Frappe"
        "Catppuccin-Latte"
        "Nordzy-cursors"
        "Nordzy-catppuccin-mocha-dark"
        "Nordzy-catppuccin-mocha-blue"
        "Nordzy-catppuccin-mocha-flamingo"
        "Nordzy-catppuccin-mocha-green"
        "Nordzy-catppuccin-mocha-lavender"
        "Nordzy-catppuccin-mocha-light"
        "Nordzy-catppuccin-mocha-maroon"
        "Nordzy-catppuccin-mocha-mauve"
        "Nordzy-catppuccin-mocha-peach"
        "Nordzy-catppuccin-mocha-pink"
        "Nordzy-catppuccin-mocha-red"
        "Nordzy-catppuccin-mocha-rosewater"
        "Nordzy-catppuccin-mocha-sapphire"
        "Nordzy-catppuccin-mocha-sky"
        "Nordzy-catppuccin-mocha-teal"
        "Nordzy-catppuccin-mocha-yellow"
        "RosePine"
        "Fuchsia"
        "Google"
        "Openzone"
        "Phinger"
        "Breeze_Hacked"
        "Layan"
        "Lyra"
        "Material"
        "Oreo_Plus"
        "Posy"
        "Simp1e"
        "Vanilla-DMZ"
        "WhiteSur"
      ];
      default = "Nordzy-catppuccin-mocha-dark";
      description = "Vector-based cursor theme to use";
    };

    cursorSize = mkOption {
      type = types.int;
      default = 24;
      description = "Cursor size in pixels";
    };
  };

  config = mkIf cfg.enable {
    # Simple cursor theming without stylix module to avoid Qt conflicts

    # Add cursor environment variables for KDE
    environment.variables = {
      XCURSOR_THEME = cfg.cursorTheme;
      XCURSOR_SIZE = toString cfg.cursorSize;
      GTK_CURSOR_THEME_NAME = cfg.cursorTheme;
      GTK_CURSOR_THEME_SIZE = toString cfg.cursorSize;
    };

    # Configure SDDM to use the same cursor theme
    services.displayManager.sddm = {
      enable = true;
      settings = {
        "X11" = {
          "ServerArguments" = "-nolisten tcp";
          "DisplayCommand" = "";
        };
        "Wayland" = {
          "DisplayCommand" = "";
        };
        "General" = {
          "CursorTheme" = cfg.cursorTheme;
          "CursorSize" = toString cfg.cursorSize;
        };
      };
    };

    # Ensure cursor and wallpaper packages are available
    environment.systemPackages = with pkgs; [
      # Vector-based cursor themes (similar to Breeze)
      bibata-cursors
      capitaine-cursors
      volantes-cursors
      catppuccin-cursors
      nordzy-cursor-theme
      rose-pine-cursor
      fuchsia-cursor
      google-cursor
      openzone-cursors
      phinger-cursors
      # Additional modern cursor themes
      breeze-hacked-cursor-theme
      layan-cursors
      lyra-cursors
      material-cursors
      oreo-cursors-plus
      posy-cursors
      simp1e-cursors
      vanilla-dmz
      whitesur-cursors
      feh # For setting wallpaper
    ];

    # Add a startup script to set the wallpaper
    systemd.user.services.set-wallpaper = {
      description = "Set wallpaper on login";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.feh}/bin/feh --bg-scale ${cfg.wallpaper}";
        User = "rain";
      };
    };
  };
}
