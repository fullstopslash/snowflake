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
          "zellij.nix"
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
  #    ------
  # | Internal |
  # | Display  |
  #    ------
  monitors = [
    {
      name = "eDP-1";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      primary = true;
      #vrr = 1;
    }
    {
      name = "HDMI-A-1";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 1920;
      workspace = "9";
    }
  ];
}
