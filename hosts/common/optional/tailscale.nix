# Tailscale configuration for all hosts
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  # Get the primary user for Tailscale operator permissions
  userNames = builtins.attrNames config.users.users;
  normalUsers = builtins.filter (n: (config.users.users."${n}".isNormalUser or false)) userNames;
  operatorUser =
    if normalUsers != []
    then builtins.head normalUsers
    else "root";
in {
  # SOPS secrets for Tailscale OAuth
  sops.secrets = {
    "tailscale/oauth_client_id" = {
      path = "/run/secrets/tailscale/oauth_client_id";
      owner = "root";
      group = "root";
      mode = "0400";
      sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
    };
    "tailscale/oauth_client_secret" = {
      path = "/run/secrets/tailscale/oauth_client_secret";
      owner = "root";
      group = "root";
      mode = "0400";
      sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
    };
  };

  # Firewall configuration for Tailscale
  networking = {
    firewall = {
      trustedInterfaces = ["tailscale0"];
    };
    nftables = {
      enable = true;
      ruleset = ''
        table inet tailscale0 {
          chain output {
            type route hook output priority -100; policy accept;
            ip daddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
          }

          chain input {
            type filter hook input priority -100; policy accept;
            ip saddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
          }
        }

        # Protect local network traffic from Tailscale interference
        table inet local_network_protection {
          chain prerouting {
            type filter hook prerouting priority -300; policy accept;
            # Mark local network traffic to bypass Tailscale routing
            # Only apply to specific local network ranges
            ip saddr 192.168.86.0/24 ct mark set 0x00000f42 meta mark set 0x6c6f6361;
          }

          chain output {
            type route hook output priority -300; policy accept;
            # Ensure local network traffic doesn't get routed through Tailscale
            # Only apply to specific local network ranges
            ip daddr 192.168.86.0/24 ct mark set 0x00000f42 meta mark set 0x6c6f6361;
          }
        }
      '';
    };
  };

  # Tailscale service configuration
  services.tailscale = {
    enable = true;
    authKeyFile = "/run/tailscale-oauth/auth.key";
    useRoutingFeatures = "none"; # Disable routing features to prevent interference with local network
    interfaceName = "tailscale0"; # optimized startup
    # Additional options to prevent interference with local network while allowing Tailnet access
    extraUpFlags = [
      "--accept-dns=true" # Don't use Tailscale DNS
      "--shields-up=false" # Don't block local network access
      "--accept-routes=false" # Don't accept routes from Tailscale
      "--operator=${operatorUser}" # Allow primary user to administer tailscale
      "--ssh" # Enable Tailscale SSH
    ];
    # Enable automatic connection on startup
    openFirewall = true;
  };

  # Systemd service to generate Tailscale auth key via OAuth
        systemd.services.tailscale-oauth-key = {
          description = "Setup Tailscale auth key from SOPS secrets";
    wantedBy = ["multi-user.target"];
    before = ["tailscaled.service"];
    after = ["network-online.target" "NetworkManager-wait-online.service"];
    wants = ["network-online.target" "NetworkManager-wait-online.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = pkgs.writeShellScript "tailscale-oauth-key" ''
        #!/usr/bin/env sh
        set -eu

        AUTH_DIR="/run/tailscale-oauth"
        AUTH_FILE="$AUTH_DIR/auth.key"

        mkdir -p "$AUTH_DIR"
        chmod 700 "$AUTH_DIR"

        CLIENT_ID=$(cat ${config.sops.secrets."tailscale/oauth_client_id".path})
        CLIENT_SECRET=$(cat ${config.sops.secrets."tailscale/oauth_client_secret".path})

        if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
          printf "%s\n" "Missing Tailscale OAuth client credentials" 1>&2
          exit 1
        fi

        # Use the auth key directly (the "client secret" is actually an auth key)
        KEY="$CLIENT_SECRET"

        umask 077
        printf "%s\n" "$KEY" > "$AUTH_FILE"
        chmod 600 "$AUTH_FILE"
      '';
    };
  };

  # Ensure tailscaled starts after OAuth key generation
        systemd.services.tailscaled = {
          after = ["tailscale-oauth-key.service" "network-online.target"];
          requires = ["tailscale-oauth-key.service"];
          wants = ["network-online.target"];
        };
        # Ensure Tailscale automatically connects on startup
        tailscale-autoconnect = {
          description = "Automatically connect to Tailscale";
          wantedBy = ["multi-user.target"];
          after = ["tailscaled.service" "tailscale-oauth-key.service"];
          requires = ["tailscaled.service" "tailscale-oauth-key.service"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.tailscale}/bin/tailscale up --auth-key=file:/run/tailscale-oauth/auth.key --accept-dns=true --shields-up=false --accept-routes=false --ssh --advertise-tags=tag:nixos";
            RemainAfterExit = true;
          };
        };
      };
    };
  };

  # Ensure Tailscale has proper permissions
  users.groups.tailscale = {};
  users.users.tailscale = {
    isSystemUser = true;
    group = "tailscale";
    extraGroups = ["networkmanager"];
  };

  # Add polkit rules specifically for Tailscale
  security.polkit.extraConfig = ''
    // Allow Tailscale service to manage network interfaces
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.NetworkManager.network-control" &&
          (subject.user == "tailscale" || subject.user == "systemd-network")) {
        return polkit.Result.YES;
      }
    });

    // Allow Tailscale to modify network configuration
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.NetworkManager") == 0 &&
          subject.user == "tailscale") {
        return polkit.Result.YES;
      }
    });
  '';

  # Install Tailscale packages
  environment.systemPackages = with pkgs; [
    ktailctl
    tailscale
  ];
}
