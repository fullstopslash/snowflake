#
# This file defines overlays/custom modifications to upstream packages
#

{ inputs, ... }:

let
  # Adds my custom packages
  # FIXME: Add per-system packages
  additions =
    final: prev:
    (prev.lib.packagesFromDirectoryRecursive {
      callPackage = prev.lib.callPackageWith final;
      directory = ../pkgs/common;
    });

  linuxModifications = final: prev: prev.lib.mkIf final.stdenv.isLinux { };

  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: let ... in {
    # ...
    # });

    #    flameshot = prev.flameshot.overrideAttrs {
    #      cmakeFlags = [
    #        (prev.lib.cmakeBool "USE_WAYLAND_GRIM" true)
    #        (prev.lib.cmakeBool "USE_WAYLAND_CLIPBOARD" true)
    #      ];
    #    };
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;
      #      overlays = [
      #     ];
    };
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
      overlays = [
        (final: prev: {
          mesa = prev.mesa.overrideAttrs (
            _:
            let
              version = "25.1.6";
              hashes = {
                "25.1.6" = "sha256-shyyezt2ez9awviatec6wvmzmujusoyxxlugs1q6q7u=";
                "25.1.5" = "sha256-azad1/wiz8d0lxpim9obp6/k7ysp12rgfe8jzrc9gl0=";
                "25.1.4" = "sha256-DA6fE+Ns91z146KbGlQldqkJlvGAxhzNdcmdIO0lHK8=";
              };
            in
            rec {
              inherit version;
              src = _prev.fetchFromGitLab {
                domain = "gitlab.freedesktop.org";
                owner = "mesa";
                repo = "mesa";
                rev = "mesa-${version}";
                sha256 = if hashes ? ${version} then hashes.${version} else "";
              };
            }
          );
        })
      ];
    };
  };

in
{
  default =
    final: prev:

    (additions final prev)
    // (modifications final prev)
    // (linuxModifications final prev)
    // (stable-packages final prev)
    // (unstable-packages final prev);
}
