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
          "browsers/brave.nix" # for testing against 'media' user
          "desktops/gtk.nix" # default is hyprland
          "helper-scripts"

          "atuin.nix"
          "ghostty.nix"
          "sops.nix"
          "xdg.nix" # file associations
        ])
    )
  );

  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;
}
