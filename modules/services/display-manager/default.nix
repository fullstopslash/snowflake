{ lib, ... }:
{
  imports = [
    # Old format (with custom options)
    ./ly.nix
  ] ++ (map (f: lib.custom.autoWrapModule "services" "display-manager" (lib.strings.removeSuffix ".nix" f) (./. + "/${f}"))
    (builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix" && f != "ly.nix")
      (builtins.attrNames (builtins.readDir ./.))
    )
  );
}
