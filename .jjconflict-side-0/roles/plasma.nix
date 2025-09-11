# Plasma desktop role
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
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
            GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=2";
          };
        };
      };
      defaultSession = "plasma";
    };
    desktopManager.plasma6.enable = true;
  };
}
