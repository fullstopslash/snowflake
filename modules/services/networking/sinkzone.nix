# Sinkzone DNS blocking service for focus/productivity
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sinkzone;
  sinkzonePkg = pkgs.callPackage ../pkgs/sinkzone/default.nix { };

  # Generate allowlist content from configuration
  allowlistContent = lib.concatStringsSep "\n" cfg.allowlist;

  # Generate YAML config
  configContent = ''
    upstream_nameservers:
    ${lib.concatMapStringsSep "\n" (ns: "  - ${ns}") cfg.upstreamNameservers}
  '';
in
{
  options.services.sinkzone = {
    enable = lib.mkEnableOption "Sinkzone DNS blocking service";

    package = lib.mkOption {
      type = lib.types.package;
      default = sinkzonePkg;
      description = "The sinkzone package to use";
    };

    dnsPort = lib.mkOption {
      type = lib.types.port;
      default = 5353;
      description = "Port for the DNS server (use non-53 to avoid systemd-resolved conflict)";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8053;
      description = "Port for the HTTP API server";
    };

    upstreamNameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "192.168.86.82"
        "1.1.1.1"
      ];
      description = "Upstream DNS servers to forward allowed queries to";
    };

    allowlist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Essential infrastructure
        "*.nixos.org"
        "*.github.com"
        "github.com"
        "*.githubusercontent.com"
        # Add more defaults as needed
      ];
      description = "Domains allowed during focus mode (supports wildcards)";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sinkzone";
      description = "User to run sinkzone as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sinkzone";
      description = "Group to run sinkzone as";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sinkzone";
      description = "Directory for sinkzone state";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add sinkzone and focus-mode script to system packages
    environment.systemPackages = [
      cfg.package
      (pkgs.writeShellScriptBin "focus-mode" ''
        #!/usr/bin/env bash
        set -euo pipefail

        SINKZONE_API="http://127.0.0.1:${toString cfg.apiPort}"

        case "''${1:-status}" in
          on)
            curl -s -X POST "$SINKZONE_API/api/focus" -d '{"enabled": true}' -H "Content-Type: application/json"
            echo "Focus mode: ON - allowlist-only DNS active"
            echo "Note: To use sinkzone for DNS, run: sudo resolvectl dns lo 127.0.0.1:${toString cfg.dnsPort}"
            ;;
          off)
            curl -s -X POST "$SINKZONE_API/api/focus" -d '{"enabled": false}' -H "Content-Type: application/json"
            echo "Focus mode: OFF - all DNS queries allowed"
            ;;
          status)
            echo "=== Focus Mode Status ==="
            curl -s "$SINKZONE_API/api/focus" | ${pkgs.jq}/bin/jq .
            echo ""
            echo "=== Recent DNS Queries ==="
            curl -s "$SINKZONE_API/api/queries" | ${pkgs.jq}/bin/jq '.[-10:]'
            ;;
          dns-on)
            sudo resolvectl dns lo 127.0.0.1:${toString cfg.dnsPort}
            sudo resolvectl domain lo "~."
            echo "System DNS now routing through sinkzone"
            ;;
          dns-off)
            sudo resolvectl revert lo
            echo "System DNS reverted to normal"
            ;;
          *)
            echo "Usage: focus-mode [on|off|status|dns-on|dns-off]"
            echo ""
            echo "Commands:"
            echo "  on       Enable focus mode (allowlist-only)"
            echo "  off      Disable focus mode (allow all)"
            echo "  status   Show current status and recent queries"
            echo "  dns-on   Route system DNS through sinkzone (requires sudo)"
            echo "  dns-off  Revert system DNS to normal (requires sudo)"
            exit 1
            ;;
        esac
      '')
    ];

    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    # Systemd service for the resolver
    systemd.services.sinkzone = {
      description = "Sinkzone DNS blocking resolver";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = cfg.dataDir;
        SINKZONE_UPSTREAM_NAMESERVERS = lib.concatStringsSep "," cfg.upstreamNameservers;
      };

      preStart = ''
        # Ensure config directory exists
        mkdir -p ${cfg.dataDir}/.sinkzone

        # Write config file
        cat > ${cfg.dataDir}/.sinkzone/sinkzone.yaml << 'EOF'
        ${configContent}
        EOF

        # Write allowlist file
        cat > ${cfg.dataDir}/.sinkzone/allowlist.txt << 'EOF'
        ${allowlistContent}
        EOF
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/sinkzone resolver --port ${toString cfg.dnsPort} --api-port ${toString cfg.apiPort}";
        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        ReadWritePaths = [ cfg.dataDir ];

        # Allow binding to privileged port if needed (not needed for 5353)
        AmbientCapabilities = lib.mkIf (cfg.dnsPort < 1024) [ "CAP_NET_BIND_SERVICE" ];
      };
    };
  };
}
