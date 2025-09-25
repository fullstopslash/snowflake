{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      map (f: "home/common/optional/${f}") [
        "browsers/brave.nix"
        "desktops/gtk.nix"
        "networking/protonvpn.nix"
      ]
    )
  );

  home.packages = builtins.attrValues {

  };

  home.file = {
  };
}
