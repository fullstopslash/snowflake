{ lib, pkgs, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      #################### Required Configs ####################
      # FIXME: remove after fixing user/home values in HM
      [
        "home/common/core"
        "home/common/core/nixos.nix"

        "home/media/common/"
      ]
      #################### Host-specific Optional Configs ####################
      ++ (map (f: "home/common/optional/${f}") [
        # FIXME: need to setup a key first
        # "atuin.nix"
        "ghostty.nix"
      ])
    )
  );

  home.packages = builtins.attrValues {
    inherit (pkgs)
      mpv # secondary media player
      ;
  };
}
