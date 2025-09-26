# Nix settings that are common to hosts and home-manager configs
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
  };

  nix = {
    # We want at least 2.30 to get the memory management improvements
    # https://discourse.nixos.org/t/nix-2-30-0-released/66449/4
    #FIXME(nix): unpin when stable catches up to 2.30+
    package = lib.mkForce pkgs.unstable.nixVersions.nix_2_30;
    optimise = {
      automatic = true;
      dates = [ "03:45" ]; # Periodically optimize the store
    };
    settings = {
      # See https://jackson.dev/post/nix-reasonable-defaults/
      connect-timeout = 5;
      log-lines = 25;
      min-free = 128000000; # 128MB
      max-free = 1000000000; # 1GB
      experimental-features = lib.mkDefault "nix-command flakes"; # Enable flakes and new 'nix' command
      warn-dirty = false;
      allow-import-from-derivation = true;
      trusted-users = [ "@wheel" ];
      builders-use-substitutes = true;
      fallback = true; # Don't hard fail if a binary cache isn't available, since some systems roam
      substituters = [
        "https://cache.nixos.org" # Official global cache
        "https://nix-community.cachix.org" # Community packages
      ];
      #extra-substituters = [
      #  "https://nix-community.cachix.org" # Nix community Cachix server
      #];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # Access token prevents github rate limiting if you have to nix flake update a bunch
    #TODO
    #extraOptions =
    #  if config ? "sops" then "!include ${config.sops.secrets."tokens/nix-access-tokens".path}" else "";

    # Disabled because we use nh
    # gc = {
    #   automatic = true;
    #   options = "--delete-older-than 10d";
    # };
  }
  // (lib.optionalAttrs pkgs.stdenv.isLinux {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well
    # NOTE: on darwin this throws
    # error: The option `nix.registry.nixpkgs.to.path' has conflicting definition values:
    #   - In `/nix/store/3m75mdiiq4bkzm5qpx6arapz042na0vh-source/modules/nix': "/nix/store/m1g5a7agja7si7y9l1lzwhp3capbv7x9-source"
    #   - In `/nix/store/3m75mdiiq4bkzm5qpx6arapz042na0vh-source/modules/nix/nixpkgs-flake.nix': "/nix/store/fj58bk5dvyaxqfrsrncfg3bn1pmdj8q2-source"
    #   Use `lib.mkForce value` or `lib.mkDefault value` to change the priority on any of these definitions.
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
  });
}
