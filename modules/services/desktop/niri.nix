{
  pkgs,
  ...
}:
{
  # Install niri (no module exists; provide via packages and session entry)

  # Provide a minimal system-wide niri config; user config overrides it
  environment.etc."niri/config.kdl".text = ''
    # Minimal niri config; user config in ~/.config/niri/config.kdl will override
    outputs {
      auto enable-all
    }
    cursor {
      accel-profile flat
    }
    binds {
      mod = "SUPER"
      # Launch terminal
      bind { mods [mod]; key "Return"; run "${pkgs.wezterm}/bin/wezterm" }
      # Exit session
      bind { mods [mod, "SHIFT"]; key "E"; action quit }
    }
  '';

  # Wayland session entry for display managers
  environment.etc."xdg/wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=Niri Wayland compositor
    Exec=${pkgs.niri}/bin/niri -c /etc/niri/config.kdl
    Type=Application
  '';

  environment.systemPackages = with pkgs; [
    niri
    wlr-randr
    wl-clipboard
    libnotify
  ];

  # Wayland portals
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  };
}
