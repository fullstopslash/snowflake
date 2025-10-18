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
      Background=/etc/qtgreet/background
      BaseColor=ff000000
      TextColor=ffffffff
    '';
    # Copy background and avatar into root-owned paths so greeter can read them
    environment.etc."qtgreet/background".source = /home/rain/Wallpapers/cool/wallhaven-qr2qx5.fav2.webp;
    environment.etc."AccountsService/icons/${config.hostSpec.username}".source = /home/rain/PirateSoftwareFlat.svg;
    environment.etc."AccountsService/users/${config.hostSpec.username}".text = ''
      [User]
      Icon=/var/lib/AccountsService/icons/${config.hostSpec.username}
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
