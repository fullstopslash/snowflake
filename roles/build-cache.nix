# Build cache role - configures Attic binary cache and distributed builds
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.roles.buildCache;
  secrets = inputs.nix-secrets;
  atticServerUrl = secrets.attic.serverUrl;
  atticCacheName = secrets.attic.cacheName;
  atticCacheUrl = "${atticServerUrl}/${atticCacheName}";

  # Determine if this is the main build machine
  isBuildMachine = config.hostSpec.hostname == "malphas";
in {
  options.roles.buildCache = {
    enable = lib.mkEnableOption "build cache configuration";

    enableBuilder = lib.mkOption {
      type = lib.types.bool;
      default = isBuildMachine;
      description = "Enable this machine as a build server for distributed builds";
    };

    enablePush = lib.mkOption {
      type = lib.types.bool;
      default = isBuildMachine;
      description = "Enable automatic pushing of built packages to the cache";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install attic client tools
    environment.systemPackages = with pkgs; [
      attic-client
    ];

    # SOPS secret for attic auth token
    sops.secrets.attic-token = {
      sopsFile = inputs.nix-secrets.outPath + "/sops/shared.yaml";
      key = "attic-token";
      owner = "root";
      mode = "0440";
    };

    # Configure Nix to use the binary cache
    nix.settings = {
      # Add attic cache as a substituter
      substituters = [
        atticCacheUrl
      ];

      # Trust the cache (required for unsigned caches or to accept signatures)
      trusted-substituters = [
        atticCacheUrl
      ];

      # If using signed caches, add the public key here
      # trusted-public-keys = [
      #   "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      #   "attic:your-public-key-here"
      # ];

      # Allow building on this machine
      builders-use-substitutes = true;
    };

    # Distributed build configuration
    nix.buildMachines = lib.mkIf (!isBuildMachine) [
      {
        hostName = "malphas";
        systems = ["x86_64-linux"];
        maxJobs = 8;
        speedFactor = 2;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        mandatoryFeatures = [];
      }
    ];

    # Enable distributed builds on non-build machines
    nix.distributedBuilds = lib.mkIf (!isBuildMachine) true;

    # Configure netrc for attic authentication
    systemd.services.attic-netrc-setup = lib.mkIf cfg.enablePush {
      description = "Setup netrc for Attic authentication";
      wantedBy = ["multi-user.target"];
      before = ["nix-daemon.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /root/.config/attic

        # Create attic config
        cat > /root/.config/attic/config.toml <<EOF
        default-server = "${atticCacheName}"

        [servers.${atticCacheName}]
        endpoint = "${atticServerUrl}"
        token = "$(cat ${config.sops.secrets.attic-token.path})"
        EOF

        chmod 600 /root/.config/attic/config.toml
      '';
    };

    # Automatic cache push service (for build machine)
    systemd.services.attic-watch = lib.mkIf cfg.enablePush {
      description = "Watch and push to Attic cache";
      wantedBy = ["multi-user.target"];
      after = ["attic-netrc-setup.service" "network-online.target"];
      wants = ["network-online.target"];
      requires = ["attic-netrc-setup.service"];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        # Watch the nix store and push new paths to attic
        # This watches for new store paths and pushes them automatically
        ExecStart = "${pkgs.attic-client}/bin/attic watch-store ${atticCacheName}";
      };
    };

    # Post-build hook to push to cache (alternative to watch service)
    # Uncomment if you prefer post-build hooks over watch-store
    # nix.extraOptions = lib.mkIf cfg.enablePush ''
    #   post-build-hook = ${pkgs.writeShellScript "attic-post-build-hook" ''
    #     set -eu
    #     set -f # disable globbing
    #     export IFS=' '
    #
    #     echo "Uploading paths to Attic cache:" $OUT_PATHS
    #     ${pkgs.attic-client}/bin/attic push ${atticCacheName} $OUT_PATHS
    #   ''}
    # '';
  };
}
