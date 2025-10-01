{ ... }:
{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "sleep 1; hyprlock";
        text = "[l]ock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "sleep 1; hyprctl dispatch exit";
        text = "[e]xit";
        keybind = "e";
      }
      {
        label = "reboot";
        action = "sleep 1; systemctl reboot";
        text = "[r]eboot";
        keybind = "r";
      }
      {
        label = "suspend";
        action = "sleep 1; systemctl suspend";
        text = "s[u]spend";
        keybind = "u";
      }
      {
        label = "hibernate";
        action = "sleep 1; systemctl hibernate";
        text = "[h]ibernate";
        keybind = "h";
      }
      {
        label = "shutdown";
        action = "sleep 1; systemctl poweroff";
        text = "[s]hutdown";
        keybind = "s";
      }
    ];
    #TODO(rice):
    style = ''
            * {
              font-family: "FiraCode Nerd Font", sans-serif;
              background-image: none;
              transition: 20ms;
            }
      #      window {
      #        background-color: rgba(24, 24, 37, 0.1);
      #      }
      #      button {
      #        color: #cdd6f4;
      #        font-size: 20px;
      #        background-repeat: no-repeat;
      #        background-position: center;
      #        background-size: 25%;
      #        border-style: solid;
      #        background-color: rgba(24, 24, 37, 0.3); /* Base Background */
      #        border: 3px solid #cdd6f4; /* Text */
      #        box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2), 0 6px 20px 0 rgba(0, 0, 0, 0.19);
      #      }
      #      button:focus,
      #      button:active,
      #      button:hover {
      #        color: #f5c2e7;
      #        background-color: rgba(24, 24, 37, 0.5); /* Slightly Darker Base */
      #        border: 3px solid #f5c2e7; /* Pink */
      #      }
      #      #logout {
      #        margin: 10px;
      #        border-radius: 20px;
      #        background-image: image(url("icons/logout.png"));
      #      }
      #      #suspend {
      #        margin: 10px;
      #        border-radius: 20px;
      #        background-image: image(url("icons/suspend.png"));
      #      }
      #      #shutdown {
      #        margin: 10px;
      #        border-radius: 20px;
      #        background-image: image(url("icons/shutdown.png"));
      #      }
      #      #reboot {
      #        margin: 10px;
      #        border-radius: 20px;
      #        background-image: image(url("icons/reboot.png"));
      #      }
      #      #lock {
      #        margin: 10px;
      #        border-radius: 20px;
      #        background-image: image(url("icons/lock.png"));
      #      }
      #      #hibernate {
      #        margin: 10px;
      #        border-radius: 20px;
      #        background-image: image(url("icons/hibernate.png"));
      #      }
      #    '';
  };
}
