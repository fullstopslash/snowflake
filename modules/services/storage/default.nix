# Storage services - borg backup, network storage
{ lib, ... }:
{
  imports = [
    # Old format (with custom options)
    ./borg.nix
  ] ++ (map (f: lib.custom.autoWrapModule "services" "storage" (lib.strings.removeSuffix ".nix" f) (./. + "/${f}"))
    (builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix" && f != "borg.nix")
      (builtins.attrNames (builtins.readDir ./.))
    )
  );
}
