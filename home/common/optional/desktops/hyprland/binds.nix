#NOTE: Actions prepended with `hy3;` are specific to the hy3 hyprland plugin
{
  config,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.settings = {
    # Reference of supported bind flags: https://wiki.hyprland.org/Configuring/Binds/#bind-flags

    #
    # ========== Mouse Binds ==========
    #
    bindm = [
      # hold SUPER + leftlclick  to move/drag active window
      "SUPER,mouse:272,movewindow"
      # hold SUPER + rightclick to resize active window
      "SUPER,mouse:273,resizewindow"
    ];
    #
    # ========== Non-consuming Binds ==========
    #
    bindn = [
      # allow tab selection using mouse
      ", mouse:272, hy3:focustab, mouse"
    ];
    #
    # ========== Repeat Binds ==========
    #
    binde = [
      # Resize active window 5 pixels in direction
      "Control_L&Shift_L&SUPER, h, resizeactive, -5 0"
      "Control_L&Shift_L&SUPER, j, resizeactive, 0 5"
      "Control_L&Shift_L&SUPER, k, resizeactive, 0 -5"
      "Control_L&Shift_L&SUPER, l, resizeactive, 5 0"

      # Volume - Output
      ", XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%"
      ", XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%"
      # Volume - Input
      ", XF86AudioRaiseVolume, exec, pactl set-source-volume @DEFAULT_SOURCE@ +5%"
      ", XF86AudioLowerVolume, exec, pactl set-source-volume @DEFAULT_SOURCE@ -5%"
    ];
    #
    # ========== One-shot Binds ==========
    #
    bind =
      let
        workspaces = [
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
          "7"
          "8"
          "9"
          "10"
          "F1"
          "F2"
          "F3"
          "F4"
          "F5"
          "F6"
          "F7"
          "F8"
          "F9"
          "F10"
          "F11"
          "F12"
        ];
        # Map keys (arrows and hjkl) to hyprland directions (l, r, u, d)
        directions = rec {
          left = "l";
          right = "r";
          up = "u";
          down = "d";
          h = left;
          l = right;
          k = up;
          j = down;
        };
        #        pactl = lib.getExe' pkgs.pulseaudio "pactl"; # installed via /hosts/common/optional/audio.nix
        terminal = config.home.sessionVariables.TERM;
        editor = config.home.sessionVariables.EDITOR;

      in
      lib.flatten [

        #
        # ========== Quick Launch ==========
        #
        "SUPER,space,exec,rofi -show drun"
        "SHIFT_SUPER,space,exec,rofi -show run"
        "SUPER,s,exec,rofi -show ssh"
        "SUPER,tab,exec,rofi -show window"

        "SUPER,Return,exec,${terminal}"
        "CTRL_SUPER,v,exec,${terminal} ${editor}"
        "CTRL_SUPER,f,exec,thunar"

        #
        # ========== Screenshotting ==========
        #
        # TODO check on status of flameshot and multimonitor wayland. as of Oct 2024, it's a clusterfuck
        # so resorting to grimblast in the meantime
        #"CTRL_SUPER,p,exec,flameshot gui"
        "CTRL_SUPER,p,exec,grimblast --notify --freeze copy area"
        ",Print,exec,grimblast --notify --freeze copy area"

        #
        # ========== Media Controls ==========
        #
        # see "binde" above for volume ctrls that need repeat binding
        # Output
        #", XF86AudioMute, exec, ${pactl} set-sink-mute @DEFAULT_SINK@ toggle"
        ", XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle"
        # Input
        #", XF86AudioMute, exec, ${pactl} set-source-mute @DEFAULT_SOURCE@ toggle"
        ", XF86AudioMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle"
        # Player
        ", XF86AudioPlay, exec, playerctl --ignore-player=firefox,chromium,brave play-pause"
        ", XF86AudioNext, exec, playerctl --ignore-player=firefox,chromium,brave next"
        ", XF86AudioPrev, exec, playerctl --ignore-player=firefox,chromium,brave previous"

        #
        # ========== Windows and Groups ==========
        #
        #NOTE: window resizing is under "Repeat Binds" above

        # Focuses the urgent window or the last window
        "SHIFTSUPER,minus,focusurgentorlast"
        #Switch focus from current to previously focused window
        "SUPER,minus,focuscurrentorlast"

        # Close the focused/active window
        "SHIFTSUPER,q,hy3:killactive"
        "SHIFTSUPER,q,killactive"

        # Fullscreen
        #"SUPER,f,fullscreen,0" # 0 - fullscreen (takes your entire screen), 1 - maximize (keeps gaps and bar(s))
        "SUPER,f,fullscreenstate,2 -1" # `internal client`, where `internal` and `client` can be -1 - current, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen
        # Float
        "SHIFTSUPER,F,togglefloating"
        # Pin Active Floating window
        "SHIFTSUPER,p, pin, active" # pins a floating window (i.e. show it on all workspaces)

        # Splits groups
        "SUPER,v,hy3:makegroup,v" # make a vertical split
        "SHIFTSUPER,v,hy3:makegroup,h" # make a horizontal split
        "SUPER,x,hy3:changegroup,opposite" # toggle btwn splits if untabbed
        #"SUPER,x,togglesplit" # superceeded by hy3:changegroup

        # Tab groups
        "SUPER,g,hy3:changegroup,toggletab" # tab or untab the group
        #"SUPER,t,lockactivegroup,toggle"
        "SUPER,apostrophe,changegroupactive,f"
        "SHIFTSUPER,apostrophe,changegroupactive,b"

        #
        # ========== Workspaces ==========
        #
        # Change workspace
        (map (
          n: if n == "10" then "SUPER,0,workspace,name:10" else "SUPER,${n},workspace,name:${n}"
        ) workspaces)

        # Special/scratch
        "SUPER,y, togglespecialworkspace"
        "SHIFTSUPER,y,movetoworkspace,special"

        # Move window to workspace
        (map (
          n:
          if n == "10" then
            "SHIFTSUPER,0,hy3:movetoworkspace,name:10"
          else
            "SHIFTSUPER,${n},hy3:movetoworkspace,name:${n}"
        ) workspaces)

        # Move focus from active window to window in specified direction
        #(lib.mapAttrsToList (key: direction: "SUPER,${key}, exec, customMoveFocus ${direction}") directions)
        (lib.mapAttrsToList (key: direction: "SUPER,${key},hy3:movefocus,${direction},warp") directions)

        # Move windows
        #(lib.mapAttrsToList (key: direction: "SHIFTSUPER,${key}, exec, customMoveWindow ${direction}") directions)
        (lib.mapAttrsToList (key: direction: "SHIFTSUPER,${key},hy3:movewindow,${direction}") directions)

        # Move workspace to monitor in specified direction
        (lib.mapAttrsToList (
          key: direction: "CTRLSHIFT,${key},movecurrentworkspacetomonitor,${direction}"
        ) directions)

        #
        # ========== Monitors==========
        #
        "SUPER, m, exec, toggleMonitors"
        "SUPER, n, exec, toggleMonitorsNonPrimary"

        #
        # ========== Misc ==========
        #
        "SHIFTSUPER,r,exec,hyprctl reload" # reload the configuration file
        "SUPER,e,exec,wlogout" # lock the wm
      ];
  };
}
