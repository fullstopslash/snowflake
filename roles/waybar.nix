{pkgs, ...}: {
  environment = {
    systemPackages = [
      pkgs.waybar
      pkgs.pavucontrol
      pkgs.bluez
      pkgs.blueman
      pkgs.overskride # Modern GTK4 Bluetooth manager for Wayland
      pkgs.bluetuith # TUI Bluetooth manager
      pkgs.kdePackages.kdeconnect-kde
    ];
    # Remove system-wide Waybar config so user config is used
  };
}
