{pkgs, ...}: let
  overlay = final: prev: {
    moondeck-buddy = prev.callPackage ../pkgs/moondeck-buddy {
      inherit (final) lib;
    };
  };
in {
  # Add an overlay locally so the package is available as pkgs.moondeck-buddy
  nixpkgs.overlays = [overlay];

  # Install the application system-wide
  environment.systemPackages = [pkgs.moondeck-buddy];
}
