# Build cache module - configures Attic binary cache and distributed builds
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.myModules.services.buildCache;
in
{
  options.myModules.services.buildCache = {
    enable = lib.mkEnableOption "binary cache configuration with Attic";

    enableBuilder = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable this machine as a build server for distributed builds.
        Other machines will offload builds to this machine.
        Set to true on the main build machine (malphas).
      '';
    };

    enablePush = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable automatic pushing of built packages to the cache.
        Only the main build machine should push to avoid conflicts.
        Set to true on the main build machine (malphas).
      '';
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://waterbug.lan:9999";
      description = "URL of the Attic server";
    };

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "system";
      description = "Name of the Attic cache";
    };

    cacheUrl = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.serverUrl}/${cfg.cacheName}";
      description = "Full URL of the Attic binary cache";
    };

    buildMachineHostname = lib.mkOption {
      type = lib.types.str;
      default = "malphas";
      description = "Hostname of the main build machine for distributed builds";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install attic client tools system-wide
    environment.systemPackages = with pkgs; [
      attic-client
    ];

    # SOPS secret for attic auth token (only on machines that push)
    sops.secrets.attic-token = lib.mkIf cfg.enablePush {
      sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
      key = "attic-token";
      owner = "root";
      mode = "0440";
    };

    # Configure Nix to use the binary cache
    nix.settings = {
      # Add attic cache as a substituter (before cache.nixos.org for priority)
      substituters = lib.mkBefore [
        cfg.cacheUrl
      ];

      # Trust the cache (required for unsigned caches)
      trusted-substituters = [
        cfg.cacheUrl
      ];

      # Add Attic cache public key to trusted keys
      trusted-public-keys = [
        "system:oio0pk/Mlb/DR3s1b78tHHmOclp82OkQrYOTRlaqays="
      ];

      # Allow build machines to use substituters when building for other machines
      builders-use-substitutes = true;

      # Increase max connections for faster downloads from cache
      http-connections = lib.mkDefault 25;

      # Enable keep-outputs and keep-derivations for better cache hits
      keep-outputs = lib.mkDefault true;
      keep-derivations = lib.mkDefault true;
    };

    # Distributed build configuration (for non-build machines)
    nix.buildMachines = lib.mkIf (!cfg.enableBuilder) [
      {
        hostName = cfg.buildMachineHostname;
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        maxJobs = 8;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
        # SSH key should be configured in ~/.ssh/config
        # The build machine needs to allow SSH access from this host
      }
    ];

    # Enable distributed builds on non-build machines
    nix.distributedBuilds = lib.mkIf (!cfg.enableBuilder) true;

    # Configure Attic client (only on machines that push)
    systemd.services.attic-config-setup = lib.mkIf cfg.enablePush {
      description = "Setup Attic client configuration";
      wantedBy = [ "multi-user.target" ];
      before = [ "nix-daemon.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /root/.config/attic

        # Create attic client config
        cat > /root/.config/attic/config.toml <<EOF
        # Attic client configuration
        # Default server for push/pull operations
        default-server = "${cfg.cacheName}"

        [servers.${cfg.cacheName}]
        endpoint = "${cfg.serverUrl}"
        token = "$(cat ${config.sops.secrets.attic-token.path})"
        EOF

        chmod 600 /root/.config/attic/config.toml

        echo "Attic client configured for cache: ${cfg.cacheName}"
      '';
    };

    # Automatic cache push service (for build machine)
    # Watches nix store and pushes new paths to attic automatically
    systemd.services.attic-watch = lib.mkIf cfg.enablePush {
      description = "Watch Nix store and push to Attic cache";
      wantedBy = [ "multi-user.target" ];
      after = [
        "attic-config-setup.service"
        "network-online.target"
      ];
      requires = [ "attic-config-setup.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "30s";

        # Watch the nix store and push new paths automatically
        ExecStart = "${pkgs.attic-client}/bin/attic watch-store ${cfg.cacheName}";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;

        # Allow access to nix store
        ReadOnlyPaths = [ "/nix/store" ];
        ReadWritePaths = [ "/root/.config/attic" ];
      };
    };

    # Optional: Post-build hook alternative to watch-store
    # Uncomment if you prefer immediate push after each build
    # nix.extraOptions = lib.mkIf cfg.enablePush ''
    #   post-build-hook = ${pkgs.writeShellScript "attic-post-build-hook" ''
    #     set -euo pipefail
    #     export IFS=' '
    #
    #     echo "Uploading paths to Attic cache:" $OUT_PATHS >&2
    #     ${pkgs.attic-client}/bin/attic push ${cfg.cacheName} $OUT_PATHS
    #   ''}
    # '';
  };
}
