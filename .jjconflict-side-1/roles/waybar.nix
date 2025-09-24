{pkgs, ...}: {
  environment = {
    systemPackages = [
      pkgs.waybar
      pkgs.pavucontrol
      pkgs.bluez
      pkgs.blueman
      pkgs.kdePackages.kdeconnect-kde
    ];
    # Remove system-wide Waybar config so user config is used
  };
}
