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
    # example = prev.example.overrideAttrs (previousAttrs: let ... in {
    # ...
    # });
    hyprland = prev.hyprland.overrideAttrs {
      package = final.stable.hyprland;
      mesa = final.unstable.mesa;
    };
    steam = prev.steam.overrideAttrs {
      mesa = final.unstable.mesa;
    };
  };

  stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;

      #      overlays = [
      #     ];
    };
  };

  unstable-packages = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
      overlays = [
        #        (unstable_final: unstable_prev: {
        #          mesa = unstable_prev.mesa.overrideAttrs (
        #            previousAttrs:
        #            let
        #              version = "25.2.2";
        #              hashes = {
        #                "25.2.2" = "sha256-9w/E5frSvCtPBI58ClXZyGyF59M+yVS4qi4khpfUZwk=";
        #                "25.1.6" = "sha256-SHYYezt2ez9awvIATEC6wVMZMuJUsOYXxlugs1Q6q7U=";
        #                "25.1.5" = "sha256-AZAd1/wiz8d0lXpim9obp6/K7ySP12rGFe8jZrc9Gl0=";
        #                "25.1.4" = "sha256-DA6fE+Ns91z146KbGlQldqkJlvGAxhzNdcmdIO0lHK8=";
        #                "25.1.3" = "sha256-BFncfkbpjVYO+7hYh5Ui6RACLq7/m6b8eIJ5B5lhq5Y=";
        #                "25.1.2" = "sha256-oE1QZyCBFdWCFq5T+Unf0GYpvCssVNOEQtPQgPbatQQ=";
        #              };
        #            in
        #            rec {
        #              inherit version;
        #              src = prev.fetchFromGitLab {
        #                domain = "gitlab.freedesktop.org";
        #                owner = "mesa";
        #                repo = "mesa";
        #                rev = "mesa-${version}";
        #                sha256 = if hashes ? ${version} then hashes.${version} else "";
        #              };
        #            }
        #          );
        #        })
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
