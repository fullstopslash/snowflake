# ly display manager - TUI login with theming support
{
  pkgs,
  lib,
  config,
  ...
}: {
  config = {
    # Console font for ly (PSF format required)
    console = {
      font = "${pkgs.terminus_font}/share/consolefonts/ter-v20n.psf.gz";
      packages = [pkgs.terminus_font];
      earlySetup = true; # Prevent font reset after driver loads
    };

    services.displayManager.ly = {
      enable = true;
      settings = {
        # Session settings
        save = true;
        default_input = "session";

        # Animation - Choose one: "doom", "matrix", "gameoflife", "colormix", "none"
        animation = "gameoflife";

        # DOOM fire animation settings
        # doom_fire_height = 8;
        # doom_fire_spread = 3;

        # Big ASCII clock (uncomment to enable)
        # bigclock = "en";
        # bigclock_12hr = false;
        # bigclock_seconds = true;

        # Visual customization
        hide_borders = false;
        hide_key_hints = false;

        # Color scheme (0xSSRRGGBB format - SS=styling, RR=red, GG=green, BB=blue)
        fg = "0x00B4BEFE"; # White foreground
        bg = "0x00181825"; # Black background
        border_fg = "0x00CBA6F7";
      };
    };

    # Disable other display managers to avoid conflicts
    services.greetd.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
  };
}
