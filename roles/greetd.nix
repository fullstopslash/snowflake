# Greetd display manager configuration role
{
  pkgs,
  lib,
  config,
  ...
}: {
  # Declare custom options for conditionally enabling auto login
  options.autoLogin = {
    enable = lib.mkEnableOption "Enable automatic login";
    username = lib.mkOption {
      type = lib.types.str;
      default = "rain";
      description = "User to automatically login";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      greetd.qtgreet
      cage
    ];

    # qtgreet appearance
    services.accounts-daemon.enable = true;
    environment.etc."qtgreet/config.ini".text = ''
      [Appearance]
      Background=/etc/qtgreet/bg.webp
      BaseColor=ff000000
      TextColor=ffffffff
    '';

    # Ensure AccountsService user file references your icon
    system.activationScripts.qtgreetAssets.text = ''
      set -eu
      install -d -m755 /etc/qtgreet || true
      install -d -m755 /var/lib/AccountsService/icons || true
      install -Dm644 /dev/stdin /var/lib/AccountsService/users/rain <<'EOF'
      [User]
      Icon=/var/lib/AccountsService/icons/rain.svg
      EOF
    '';

    services.greetd = {
      enable = true;
      restart = true;
      settings = {
        default_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.qtgreet}/bin/qtgreet";
          user = "rain";
        };

        initial_session = lib.mkIf config.autoLogin.enable {
          command = "${pkgs.hyprland}/bin/Hyprland";
          user = "${config.autoLogin.username}";
        };
      };
    };

    # Disable SDDM to avoid conflicts
    services.displayManager.sddm.enable = false;
  };
}
