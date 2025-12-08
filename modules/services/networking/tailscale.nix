# Tailscale role
{
  pkgs,
  config,
  ...
}:
let
  userNames = builtins.attrNames config.users.users;
  normalUsers = builtins.filter (n: (config.users.users."${n}".isNormalUser or false)) userNames;
  operatorUser = if normalUsers != [ ] then builtins.head normalUsers else "root";
in
{
  sops.secrets = {
    vpn-preauth = {
      key = "vpn-preauth";
      owner = "root";
      neededForUsers = true;
    };
    tailscale-oauth-client-id = {
      key = "tailscale_oauth_client_id";
      owner = "root";
      neededForUsers = true;
    };
    tailscale-oauth-client-secret = {
      key = "tailscale_oauth_client_secret";
      owner = "root";
      neededForUsers = true;
    };
  };

  networking = {
    firewall = {
      trustedInterfaces = [ "tailscale0" ];
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
  };

  systemd = {
    services = {
      tailscale-oauth-key = {
        description = "Generate Tailscale auth key via OAuth";
        wantedBy = [ "multi-user.target" ];
        before = [ "tailscaled.service" ];
        after = [
          "network-online.target"
          "NetworkManager-wait-online.service"
        ];
        wants = [
          "network-online.target"
          "NetworkManager-wait-online.service"
        ];
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

            CLIENT_ID=$(cat ${config.sops.secrets."tailscale-oauth-client-id".path})
            CLIENT_SECRET=$(cat ${config.sops.secrets."tailscale-oauth-client-secret".path})

            if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
              printf "%s\n" "Missing Tailscale OAuth client credentials" 1>&2
              exit 1
            fi

            # Obtain OAuth access token with retries to handle early boot networking
            ACCESS_TOKEN=""
            i=0
            while [ "$i" -lt 10 ] && [ -z "$ACCESS_TOKEN" ]; do
              TOKEN_RESP=$(${pkgs.curl}/bin/curl --fail -sS \
                -u "$CLIENT_ID:$CLIENT_SECRET" \
                -d "grant_type=client_credentials" \
                -d "scope=auth_keys" \
                https://api.tailscale.com/api/v2/oauth/token || true)
              ACCESS_TOKEN=$(printf "%s" "$TOKEN_RESP" | ${pkgs.jq}/bin/jq -r '.access_token // empty') || true
              if [ -z "$ACCESS_TOKEN" ]; then
                i=$((i + 1))
                printf "%s\n" "Waiting for OAuth token (attempt $i/10)" 1>&2
                sleep 3
              fi
            done
            if [ -z "$ACCESS_TOKEN" ]; then
              printf "%s\n" "Failed to obtain OAuth access token after retries" 1>&2
              printf "%s\n" "Last response: $TOKEN_RESP" 1>&2
              exit 1
            fi

            CREATE_PAYLOAD='{
              "capabilities": {
                "devices": {
                  "create": {
                    "reusable": false,
                    "ephemeral": false,
                    "preauthorized": true,
                    "tags": ["tag:nixos"]
                  }
                }
              }
            }'

            # Create a Tailscale auth key with retries
            KEY=""
            j=0
            while [ "$j" -lt 10 ] && [ -z "$KEY" ]; do
              KEY_RESP=$(${pkgs.curl}/bin/curl --fail -sS \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$CREATE_PAYLOAD" \
                https://api.tailscale.com/api/v2/tailnet/-/keys || true)
              KEY=$(printf "%s" "$KEY_RESP" | ${pkgs.jq}/bin/jq -r '.key // empty') || true
              if [ -z "$KEY" ]; then
                j=$((j + 1))
                printf "%s\n" "Waiting for auth key (attempt $j/10)" 1>&2
                sleep 3
              fi
            done
            if [ -z "$KEY" ]; then
              printf "%s\n" "Failed to create Tailscale auth key after retries" 1>&2
              printf "%s\n" "Last response: $KEY_RESP" 1>&2
              exit 1
            fi

            umask 077
            printf "%s\n" "$KEY" > "$AUTH_FILE"
            chmod 600 "$AUTH_FILE"
          '';
        };
      };
      tailscaled = {
        after = [
          "tailscale-oauth-key.service"
          "network-online.target"
        ];
        requires = [ "tailscale-oauth-key.service" ];
        wants = [ "network-online.target" ];
      };
    };
  };

  # Ensure Tailscale has proper permissions
  users.groups.tailscale = { };
  users.users.tailscale = {
    isSystemUser = true;
    group = "tailscale";
    extraGroups = [ "networkmanager" ];
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

  environment.systemPackages = with pkgs; [
    ktailctl
    tailscale
  ];
}
