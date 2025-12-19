{ lib, ... }:
{
  imports = [
    # Old format (with custom options)
    ./bitwarden.nix
    ./yubikey.nix
  ] ++ (map (f: lib.custom.autoWrapModule "services" "security" (lib.strings.removeSuffix ".nix" f) (./. + "/${f}"))
    (builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix" && f != "bitwarden.nix" && f != "yubikey.nix")
      (builtins.attrNames (builtins.readDir ./.))
    )
  );
}
