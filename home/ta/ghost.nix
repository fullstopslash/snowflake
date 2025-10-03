{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      [
        #
        # ========== Required Configs ==========
        #
        #FIXME: after fixing user/home values in HM
        "home/common/core"
        "home/common/core/nixos.nix"

        "home/ta/common/nixos.nix"
      ]
      ++
        #
        # ========== Host-specific Optional Configs ==========
        #
        (map (f: "home/common/optional/${f}") [
          "browsers"
          "comms"
          "desktops" # default is hyprland
          "development"
          "gaming"
          "helper-scripts"
          "media"
          "tools"

          "atuin.nix"
          "xdg.nix" # file associations
          "sops.nix"
          "zellij/default.nix"
        ])
    )
  );

  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # This uses the nix-config/modules/home/montiors.nix module which defaults to enabled.
  # Your nix-config/home-manger/<user>/common/optional/desktops/foo.nix WM config should parse and apply these values to it's monitor settings
  # If on hyprland, use `hyprctl monitors` to get monitor info.
  # https://wiki.hyprland.org/Configuring/Monitors/
  #           ------
  #        | HDMI-A-1 |
  #           ------
  #  ------   ------   ------
  # | DP-2 | | DP-1 | | DP-3 |
  #  ------   ------   ------
  monitors = [
    {
      name = "DP-2";
      width = 2560;
      height = 2880;
      refreshRate = 60;
      x = -2560;
      workspace = "8";
    }
    {
      name = "DP-1";
      width = 3840;
      height = 2160;
      refreshRate = 60;
      vrr = 1;
      primary = true;
    }
    {
      name = "DP-3";
      width = 2560;
      height = 2880;
      refreshRate = 60;
      x = 3840;
      workspace = "10";
    }
    {
      name = "HDMI-A-1";
      width = 2560;
      height = 1440;
      refreshRate = 240;
      y = -1440;
      transform = 2;
      workspace = "9";
    }
  ];
}
