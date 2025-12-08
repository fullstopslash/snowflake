#
# This file defines overlays/custom modifications to upstream packages
#

{ inputs, ... }:

let
  # Adds custom packages from pkgs/common
  additions =
    final: prev:
    (prev.lib.packagesFromDirectoryRecursive {
      callPackage = prev.lib.callPackageWith final;
      directory = ../pkgs/common;
    });

  # Package modifications - only use if actually needed
  # Uncomment and fix if specific overrides are required
  # modifications = final: prev: {
  #   # Example: Use stable version of a package
  #   # hyprland = final.stable.hyprland;
  #
  #   # Example: Override with specific dependency
  #   # steam = prev.steam.override { mesa = final.unstable.mesa; };
  # };

  # Access to nixpkgs-stable packages via pkgs.stable.*
  stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };

  # Access to nixpkgs-unstable packages via pkgs.unstable.*
  unstable-packages = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };

in
{
  default =
    final: prev:
    (additions final prev)
    # // (modifications final prev)  # Uncomment if modifications are added
    // (stable-packages final prev)
    // (unstable-packages final prev);
}
