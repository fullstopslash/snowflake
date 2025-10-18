#
# greeter -> tuigreet https://github.com/apognu/tuigreet?tab=readme-ov-file
# display manager -> greetd https://man.sr.ht/~kennylevinsen/greetd/
#

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.autoLogin;
in
{
  # Declare custom options for conditionally enabling auto login
  options.autoLogin = {
    enable = lib.mkEnableOption "Enable automatic login";

    username = lib.mkOption {
      type = lib.types.str;
      default = "guest";
      description = "User to automatically login";
    };
  };

  config = {
    environment.systemPackages = [ pkgs.greetd.qtgreet pkgs.cage ];

    # qtgreet appearance
    services.accounts-daemon.enable = true;
    environment.etc."qtgreet/config.ini".text = ''
      [Appearance]
      Background=/etc/qtgreet/bg.webp
      BaseColor=ff000000
      TextColor=ffffffff
    '';
    # Ensure AccountsService user file references your icon; use in-place assets you provided
    system.activationScripts.qtgreetAssets.text = ''
      set -eu
      install -d -m755 /etc/qtgreet || true
      install -d -m755 /var/lib/AccountsService/icons || true
      install -Dm644 /dev/stdin /var/lib/AccountsService/users/${config.hostSpec.username} <<'EOF'
      [User]
      Icon=/var/lib/AccountsService/icons/${config.hostSpec.username}.svg
      EOF
    '';
    services.greetd = {
      enable = true;

      restart = true;
      settings = {
        default_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.qtgreet}/bin/qtgreet";
          user = lib.mkForce config.hostSpec.username;
        };

        initial_session = lib.mkIf cfg.enable {
          command = "${pkgs.hyprland}/bin/Hyprland";
          user = "${cfg.username}";
        };
      };
    };
  };
}
