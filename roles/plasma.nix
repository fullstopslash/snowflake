# Plasma desktop role
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Force stable xwayland to override Plasma's default
    stable.xwayland
    # KDE utilities
    kdePackages.kdialog
    kdePackages.ksshaskpass
    kdePackages.konqueror
    kdePackages.kcharselect
    kdePackages.kcolorchooser
    kdePackages.kcontacts
    kdePackages.akonadi
    kdePackages.akonadi-contacts
    kdePackages.akonadi-calendar
    kdePackages.qtmultimedia
    kdePackages.kio
    sddm-astronaut
    catppuccin-sddm
    where-is-my-sddm-theme
  ];

  # environment.systemPackages = [(
  #   pkgs.catppuccin-sddm.override {
  #     flavor = "mocha";
  #     font  = "Noto Sans";
  #     fontSize = "9";
  #     background = "${./wallpaper.png}";
  #     loginBackground = true;
  #   }
  # )];

  services = {
    displayManager = {
      sddm = {
        enable = true;
        enableHidpi = true;
        wayland.enable = true;
        # theme = "catppuccin-mocha";
        theme = "sddm-astronaut-theme";
        settings = {
          General = {
            DisplayServer = "wayland";
            GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=2 QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
          };
          Wayland = {
            CompositorCommand = "Hyprland --no-lockscreen --no-global-shortcuts";
          };
        };
      };
      defaultSession = "hyprland";
    };
    desktopManager.plasma6.enable = true;
  };

  # KWallet + PAM integration scoped to Plasma/S.D.D.M.
  security.pam.services = {
    login.kwallet.enable = true;
    sddm.kwallet.enable = true;
    sddm-greeter.kwallet.enable = true;
  };

  # KWallet runtime config
  environment.etc."kwalletrc".text = ''
    [Wallet]
    Enabled=true
    AutoClose=false
    AutoCloseTimeout=300
    AutoCloseOnIdle=true
    AutoCloseOnIdleTimeout=300
    UseBlowfish=false
    UseGPG=true
    UseKSecretsService=true
    UseKSecretsServiceTimeout=300
    UseKSecretsServiceAutoClose=true
    UseKSecretsServiceAutoCloseTimeout=300
  '';

  # kwalletd user service for Plasma sessions
  systemd.user.services.kwalletd = {
    description = "KWallet user daemon";
    after = ["plasma-workspace.service" "dbus.service"];
    wantedBy = ["plasma-workspace.target" "default.target"]; # ensure it starts in Plasma sessions
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.kwallet}/bin/kwalletd6";
      Restart = "on-failure";
      RestartSec = 1;
      Type = "simple";
    };
  };
}
