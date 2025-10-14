{
  pkgs,
  config,
  lib,
  ...
}: let
  # Custom scripts directory
  scriptsDir = ./user-scripts;

  # Make scripts available as derivations
  mkScript = name: pkgs.writeShellScript name (builtins.readFile "${scriptsDir}/${name}");
in {
  wayland.windowManager.hyprland = {
    settings = {
      #
      # ========== Main Modifier Key ==========
      #
      "$mainMod" = "SUPER";

      #
      # ========== Custom Environment Variables ==========
      #
      env = lib.mkAfter [
        "WLR_RENDERER,vulkan"
        "QT_STYLE_OVERRIDE,Breeze"
        "GTK_THEME,Breeze"
        "XDG_MENU_PREFIX,hyprland-"
        "_JAVA_AWT_WM_NONREPARENTING,1"
      ];

      #
      # ========== Custom Programs ==========
      #
      "$terminal" = "kitty";
      "$fileManager" = "dolphin";
      "$browser" = "firefox";
      "$menu" = "wofi --show drun";

      #
      # ========== Custom Animations ==========
      #
      animations = {
        enabled = true;

        bezier = [
          "wind, 0.05, 0.9, 0.1, 1.05"
          "winIn, 0.1, 1.1, 0.1, 1.1"
          "winOut, 0.3, -0.3, 0, 1"
          "liner, 1, 1, 1, 1"
        ];

        animation = [
          "windows, 1, 6, wind, slide"
          "windowsIn, 1, 3, winIn, slide"
          "windowsOut, 1, 3, winOut, slide"
          "windowsMove, 1, 3, wind, slide"
          "border, 1, 1, liner"
          "fade, 1, 10, default"
          "workspaces, 1, 5, wind, slidefadevert"
        ];
      };

      #
      # ========== Custom General Settings ==========
      #
      general = {
        gaps_in = lib.mkForce 4;
        gaps_out = lib.mkForce 6;
        border_size = lib.mkForce 2;
        "col.active_border" = lib.mkForce "rgba(b377f0cc) rgba(8c66cccc) 45deg";
        "col.inactive_border" = lib.mkForce "rgba(595959aa)";
        resize_on_border = lib.mkForce true;
        allow_tearing = lib.mkForce false;
        no_border_on_floating = lib.mkForce true;
        layout = lib.mkForce "dwindle";
      };

      #
      # ========== Custom Decoration ==========
      #
      decoration = {
        rounding = lib.mkForce 10;
        active_opacity = lib.mkForce 1.0;
        inactive_opacity = lib.mkForce 0.90;
        dim_inactive = lib.mkForce true;
        dim_strength = lib.mkForce 0.05;

        shadow = {
          enabled = lib.mkForce true;
          range = lib.mkForce 4;
          render_power = lib.mkForce 5;
          color = lib.mkForce "rgba(1a1a1aee)";
        };

        blur = {
          enabled = lib.mkForce false;
          size = lib.mkForce 1;
          passes = lib.mkForce 2;
          vibrancy = lib.mkForce 0.1696;
        };
      };

      #
      # ========== Custom Input ==========
      #
      input = {
        kb_rules = lib.mkForce "";
        scroll_method = lib.mkForce "on_button_down";
        scroll_button = lib.mkForce 276; # browser forward
        natural_scroll = lib.mkForce true;
        follow_mouse = lib.mkForce 1;
        sensitivity = lib.mkForce 0;
      };

      #
      # ========== Custom Misc Settings ==========
      #
      misc = {
        vfr = lib.mkForce true;
        vrr = lib.mkForce 0;
        force_default_wallpaper = lib.mkForce (-1);
        disable_hyprland_logo = lib.mkForce false;
        disable_autoreload = lib.mkForce true;
        animate_mouse_windowdragging = lib.mkForce false;
        animate_manual_resizes = lib.mkForce true;
      };

      #
      # ========== Media Window Positioning Variables ==========
      #
      "$pinnedXLef" = "8";
      "$pinnedXRig" = "1272";
      "$pinnedYHig" = "36";
      "$pinnedYLow" = "712";
      "$pinnedSizeX" = "640";
      "$pinnedSizeY" = "360";

      #
      # ========== Custom Window Rules (PiP, Media, etc) ==========
      #
      windowrulev2 = lib.mkAfter [
        # MPV rules (PiP)
        "float, class:^(mpv)$"
        "pin, class:^(mpv)$"
        "size $pinnedSizeX $pinnedSizeY, class:^(mpv)$"
        "opacity 1.0 override 1.0 override, class:^(mpv)$"
        "move $pinnedXRig $pinnedYHig, class:^(mpv)$"
        "noinitialfocus, class:^(mpv)$"

        # Firefox PiP rules
        "float, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "pin, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "size $pinnedSizeX $pinnedSizeY, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "opacity 1.0 override 1.0 override, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "move $pinnedXRig $pinnedYHig, class:^(firefox)$, title:^(Picture-in-Picture)$"

        # Steam rules
        "stayfocused, title:^()$,class:^(steam)$"
        "minsize 1 1, title:^()$,class:^(steam)$"

        # Jellyfin Media Player
        "workspace 6,title:^(Jellyfin Media Player)$"

        # Firefox workspace
        "workspace 2,class:^(firefox)$"

        # Fix dragging issues with XWayland
        "nofocus, class:^$, title:^$, xwayland:1, floating:1, fullscreen:0, pinned:0"

        # Waybar rules
        "float,title:^waybar$"
        "noborder,title:^waybar$"
      ];

      #
      # ========== Custom Keybindings ==========
      #
      bind = lib.mkAfter [
        # Wallpaper controls
        "$mainMod, Menu, exec, ${pkgs.coreutils}/bin/env wall-roulette"
        "$mainMod SHIFT, Menu, exec, ${pkgs.coreutils}/bin/env wall-roulette fav"
        "$mainMod ALT SHIFT, Menu, exec, ${pkgs.coreutils}/bin/env wall-roulette del"

        # Window management
        "$mainMod, W, killactive"
        "$mainMod, R, exec, hyprctl reload"
        "$mainMod, E, exec, $fileManager"

        # Terminal and apps
        "$mainMod SHIFT, T, exec, $terminal"
        "$mainMod, T, exec, ${mkScript "focus-or-launch.sh"} $terminal $terminal"
        "$mainMod, F, exec, ${mkScript "focus-or-launch.sh"} $browser $browser"

        # Media apps
        "$mainMod, A, exec, ${mkScript "focus-priority-or-fallback.sh"} class=gamescope -- \"STEAM_MULTIPLE_XWAYLANDS=1 DXVK_HDR=1 ENABLE_HDR_WSI=1 gamescope -f -e -h 1080 -H 2160 -r 120.0 --xwayland-count 2 --prefer-vk-device --hdr-itm-enable --hdr-enabled --hdr-debug-force-output --force-grab-cursor -- steam -gamepadui -steamos\""
        "$mainMod, C, exec, ${mkScript "focus-priority-or-fallback.sh"} class=cursor -- cursor"
        "$mainMod, M, exec, ${mkScript "focus-priority-or-fallback.sh"} title=Picture-in-Picture class=mpv class=streamlink-twitch-gui class=com.github.iwalton3.jellyfin-media-player -- \"flatpak run --branch=stable --arch=x86_64 --command=jellyfinmediaplayer com.github.iwalton3.jellyfin-media-player\""

        # Media window positioning (vim-like: h=left, j=down, k=up, l=right)
        "$mainMod CTRL, H, exec, ${mkScript "move-media-window.sh"} $pinnedXLef $pinnedYHig $pinnedSizeX $pinnedSizeY"
        "$mainMod CTRL, J, exec, ${mkScript "move-media-window.sh"} $pinnedXLef $pinnedYLow $pinnedSizeX $pinnedSizeY"
        "$mainMod CTRL, K, exec, ${mkScript "move-media-window.sh"} $pinnedXRig $pinnedYHig $pinnedSizeX $pinnedSizeY"
        "$mainMod CTRL, L, exec, ${mkScript "move-media-window.sh"} $pinnedXRig $pinnedYLow $pinnedSizeX $pinnedSizeY"

        # Launcher
        "$mainMod, Q, exec, $menu"
        "ALT, space, exec, $menu"

        # Workspaces
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move to workspace
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Isolate focused window
        "$mainMod ALT, 1, exec, ${mkScript "isolate-focused-window.sh"} 1"
        "$mainMod ALT, 2, exec, ${mkScript "isolate-focused-window.sh"} 2"
        "$mainMod ALT, 3, exec, ${mkScript "isolate-focused-window.sh"} 3"
        "$mainMod ALT, 4, exec, ${mkScript "isolate-focused-window.sh"} 4"
        "$mainMod ALT, 5, exec, ${mkScript "isolate-focused-window.sh"} 5"
        "$mainMod ALT, 6, exec, ${mkScript "isolate-focused-window.sh"} 6"
        "$mainMod ALT, 7, exec, ${mkScript "isolate-focused-window.sh"} 7"
        "$mainMod ALT, 8, exec, ${mkScript "isolate-focused-window.sh"} 8"
        "$mainMod ALT, 9, exec, ${mkScript "isolate-focused-window.sh"} 9"
        "$mainMod ALT, 0, exec, ${mkScript "isolate-focused-window.sh"} 10"

        # Special workspace toggle
        "SUPER, grave, exec, hyprctl dispatch togglespecialworkspace magic && hyprctl dispatch movetoworkspace special:magic"
        "$mainMod, s, togglespecialworkspace, magic"

        # Fullscreen toggles
        "SUPER SHIFT, F, fullscreen"
        "SUPER ALT, F, exec, ${mkScript "fullscreen-media-toggle.sh"}"

        # Vim-like window movement
        "$mainMod SHIFT,h,movewindow,l"
        "$mainMod SHIFT,j,movewindow,d"
        "$mainMod SHIFT,k,movewindow,u"
        "$mainMod SHIFT,l,movewindow,r"

        # Layout controls
        "$mainMod,space,layoutmsg,togglesplit"
        "$mainMod, Return, layoutmsg,swapwithmaster"
        "$mainMod, Return, layoutmsg, focusmaster"
        "SUPER_ALT, m, exec, hyprctl keyword general:layout master"
        "SUPER_ALT, d, exec, hyprctl keyword general:layout dwindle"

        # Float and pin
        "$mainMod, O, togglefloating"
        "$mainMod, p, exec, ${mkScript "pin-and-float.sh"}"
        "$mainMod, n, pin"

        # Vim-like focus navigation
        "$mainMod,h,movefocus,l"
        "$mainMod,j,movefocus,d"
        "$mainMod,k,movefocus,u"
        "$mainMod,l,movefocus,r"

        # Audio toggle
        ", XF86AudioMute, exec, ${mkScript "audio-toggle.sh"}"

        # Window resizing
        "$mainMod, left, resizeactive, -50 0"
        "$mainMod, right, resizeactive, 50 0"
        "$mainMod, up, resizeactive, 0 -50"
        "$mainMod, down, resizeactive, 0 50"
      ];

      #
      # ========== Mouse bindings ==========
      #
      bindm = lib.mkAfter [
        # "$mainMod, mouse_down, workspace, e+1"
        # "$mainMod, mouse_up, workspace, e-1"
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };

    # NOTE: extraConfig disabled for now - media keys handled by binds.nix
    # extraConfig = ''
    #   bindl = , XF86AudioNext, exec, playerctl next
    #   bindl = , XF86AudioPause, exec, playerctl play-pause
    # '';
  };
}
