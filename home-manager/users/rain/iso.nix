{ lib, ... }:
{
  imports = map lib.custom.relativeToRoot ([
    "home-manager/common/core"
    "home-manager/common/core/nixos.nix"
  ]);
}
