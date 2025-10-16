# SDDM display manager configured for Wayland
{pkgs, ...}: {
  services = {
    displayManager = {
      sddm = {
        enable = true;
        enableHidpi = true;
        wayland.enable = true;
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
  };

  environment.systemPackages = with pkgs; [
    sddm-astronaut
    catppuccin-sddm
    where-is-my-sddm-theme
  ];

  # Ensure SDDM has access to the greeter
  systemd.services.sddm.serviceConfig = {
    Type = "notify";
    NotifyAccess = "all";
  };
}
