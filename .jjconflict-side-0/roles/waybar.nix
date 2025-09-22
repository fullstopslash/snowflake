{pkgs, ...}: {
  environment = {
    systemPackages = [
      pkgs.waybar
      pkgs.pavucontrol
      pkgs.bluez
      pkgs.blueman
      pkgs.kdePackages.kdeconnect-kde
    ];

    # System-wide Waybar configuration modeled after shell-ninja/hyprconf-install
    etc."xdg/waybar/config.jsonc".text = ''
      // Waybar configuration
      {
        "layer": "top",
        "position": "top",
        "height": 34,
        "margin": "6 6 0 6",
        "spacing": 8,

        "modules-left": ["hyprland/workspaces", "hyprland/window"],
        "modules-center": ["clock"],
        "modules-right": ["custom/kdeconnect", "bluetooth", "tray", "cpu", "memory", "temperature", "pulseaudio", "network"],

        "hyprland/workspaces": {
          "format": "{icon}",
          "format-icons": {
            "active": "",
            "default": ""
          }
        },

        "hyprland/window": {
          "max-length": 80,
          "separate-outputs": true
        },

        "clock": {
          "format": "{:%a %b %d  %H:%M}",
          "tooltip": true,
          "tooltip-format": "{:%Y-%m-%d %H:%M:%S}"
        },

        "cpu": {
          "format": " {usage}%",
          "tooltip": false
        },

        "memory": {
          "format": " {used:0.1f}G",
          "tooltip": false
        },

        "temperature": {
          "critical-threshold": 85,
          "format": " {temperatureC}°C"
        },

        "pulseaudio": {
          "format": "{icon} {volume}%",
          "format-muted": "",
          "format-icons": { "default": ["", "", ""] },
          "on-click": "pavucontrol",
        },

        "network": {
          "format-wifi": " {essid} {signalStrength}%",
          "format-ethernet": "󰈀 {ifname}",
          "format-disconnected": "󰈂",
          "tooltip": false
        },

        "bluetooth": {
          "format": "",
          "format-connected": " {num_connections}",
          "format-disabled": " x",
          "format-off": " off",
          "on-click": "blueman-manager",
          "tooltip": true
        },



        "tray": {
          "icon-size": 16,
          "spacing": 8,
          "show-passive-items": false
        }
      }
    '';

    etc."xdg/waybar/style.css".text = ''
      /* Waybar style modeled after shell-ninja/hyprconf-install with Catppuccin-like palette */
      * {
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
        font-size: 12pt;
      }

      window#waybar {
        background: rgba(24, 24, 37, 0.6);
        border-radius: 12px;
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        margin: 6px 4px;
        border-radius: 8px;
        color: #a6adc8;
        background: transparent;
      }

      #workspaces button.active {
        background: #89b4fa22;
        color: #89b4fa;
      }

      #clock, #cpu, #memory, #temperature, #pulseaudio, #network, #tray, #window {
        padding: 0 10px;
        margin: 6px 4px;
        border-radius: 8px;
        background: #1e1e2e88;
      }

      #pulseaudio.muted { color: #f38ba8; }
    '';
  };
}
