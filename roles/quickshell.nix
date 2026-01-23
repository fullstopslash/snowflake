{pkgs, lib, ...}: {
  environment.systemPackages = [
    pkgs.quickshell
  ];

  # Systemd user service for quickshell
  systemd.user.services.quickshell = {
    description = "Quickshell Wayland shell";
    wantedBy = ["hyprland-session.target"];
    partOf = ["hyprland-session.target"];
    after = ["hyprland-session.target" "hyprland-environment.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 1;
      # Include tools needed by shell scripts (container-health.sh)
      Environment = "PATH=${lib.makeBinPath [pkgs.bash pkgs.curl pkgs.jaq pkgs.coreutils]}:$PATH";
    };
  };
}
