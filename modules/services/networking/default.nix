{ lib, ... }:
{
  imports = [
    # Old format (with custom options)
    ./ssh.nix
    ./sinkzone.nix
  ] ++ (map (f: lib.custom.autoWrapModule "services" "networking" (lib.strings.removeSuffix ".nix" f) (./. + "/${f}"))
    (builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix" && f != "ssh.nix" && f != "sinkzone.nix")
      (builtins.attrNames (builtins.readDir ./.))
    )
  );
}
