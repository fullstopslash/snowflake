{
  pkgs,
  config,
  lib,
  ...
}:

{
  imports = [
    ./binds.nix
    ./scripts.nix
    ./hyprlock.nix
    ./wlogout.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      enable = true;
      variables = [ "--all" ]; # fix for https://wiki.hyprland.org/Nix/Hyprland-on-Home-Manager/#programs-dont-work-in-systemd-services-but-do-on-the-terminal
    };

    plugins = [
      pkgs.hyprlandPlugins.hy3
      #pkgs.unstable.hyprlandPlugins.hy3
    ];

    settings = {
      debug = {
        disable_logs = false;
      };
      #
      # ========== Environment Vars ==========
      #
      env = [
        "NIXOS_OZONE_WL, 1" # for ozone-based and electron apps to run on wayland
        "MOZ_ENABLE_WAYLAND, 1" # for firefox to run on wayland
        "MOZ_WEBRENDER, 1" # for firefox to run on wayland
        "XDG_SESSION_TYPE,wayland"
        "WLR_NO_HARDWARE_CURSORS,1"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
        "QT_QPA_PLATFORM,wayland"
        "HYPRCURSOR_THEME,rose-pine-hyprcursor" # this will be better than default for now
      ];

      #
      # ========== Monitor ==========
      #
      # parse the monitor spec defined in nix-config/home/<user>/<host>.nix
      monitor = (
        map (
          m:
          "${m.name},${
            if m.enabled then
              "${toString m.width}x${toString m.height}@${toString m.refreshRate}"
              + ",${toString m.x}x${toString m.y},1"
              + ",transform,${toString m.transform}"
              + ",vrr,${toString m.vrr}"
            else
              "disable"
          }"
        ) (config.monitors)
      );

      workspace = (
        let
          workspaceIDs = lib.flatten [
            (lib.range 1 10) # workspaces 1 through 10, Hyprland does not allow ws 0 :/
            "special" # add the special/scratchpad ws
          ];
          isPrimary = x: x ? primary && x.primary;
          primary = lib.lists.findFirst isPrimary { } config.monitors;
        in
        # workspace structure to build "[workspace], monitor:[name], default:[bool], persistent:[bool]"
        map (
          id:
          let
            id_as_string = toString id;
            # determine if the monitor is intended to display a specific workspace
            monitor = lib.lists.findFirst (
              x: x ? "workspace" && id_as_string == x.workspace
            ) primary config.monitors;
            # workspace 1 and any workspaces specific to the non-primary monitors are persistent
            persistent = if (id == 1 || !(isPrimary monitor)) then ", persistent:true" else "";
          in
          "${id_as_string}, monitor:${monitor.name}, default:true" + persistent
        ) workspaceIDs
      );
      #
      # ========== Behavior ==========
      #
      binds = {
        workspace_center_on = 1; # Whether switching workspaces should center the cursor on the workspace (0) or on the last active window for that workspace (1)
        movefocus_cycles_fullscreen = false; # If enabled, when on a fullscreen window, movefocus will cycle fullscreen, if not, it will move the focus in a direction.
      };
      input = {
        numlock_by_default = true; # numlock key disabled via keyd in nixos.nix
        follow_mouse = 2;
        # follow_mouse options:
        # 0 - Cursor movement will not change focus.
        # 1 - Cursor movement will always change focus to the window under the cursor.
        # 2 - Cursor focus will be detached from keyboard focus. Clicking on a window will move keyboard focus to that window.
        # 3 - Cursor focus will be completely separate from keyboard focus. Clicking on a window will not change keyboard focus.
        mouse_refocus = false;
        touchpad = {
          disable_while_typing = true;
        };
      };
      cursor.inactive_timeout = 10;
      misc = {
        disable_hyprland_logo = true;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        #disable_autoreload = true;
        new_window_takes_over_fullscreen = 2; # 0 - behind, 1 - takes over, 2 - unfullscreen/unmaxize
        middle_click_paste = false;
      };

      #
      # ========== Appearance ==========
      #
      general = {
        gaps_in = 6;
        gaps_out = 6;
        border_size = 0;
        resize_on_border = true;
        hover_icon_on_border = true;
        allow_tearing = true; # used to reduce latency and/or jitter in games
      };
      decoration = {
        active_opacity = 1.0;
        inactive_opacity = 0.85;
        fullscreen_opacity = 1.0;
        rounding = 10;
        blur = {
          enabled = true;
          size = 4;
          passes = 2;
          new_optimizations = true;
          popups = true;
        };
        shadow = {
          enabled = true;
          range = 12;
          #offset = "3 3";
          color = lib.mkForce "0xffff9400";
          color_inactive = lib.mkForce "0xff2d2d30";
        };
      };
      # group = {
      #groupbar = {
      #          };
      #};

      #
      # ========== Auto Launch ==========
      #
      # exec-once = ''${startupScript}/path'';
      # To determine path, run `which foo`
      exec-once =
        if config.hostSpec.hostName == "ghost" then
          [
            ''${pkgs.waypaper}/bin/waypaper --restore''
            ''[workspace 10 silent]${pkgs.ghostty}/bin/ghostty --title=btop -e btop''
            ''[workspace 10 silent]${pkgs.ghostty}/bin/ghostty --title=amdgpu_top -e amdgpu_top --dark''
            ''[workspace 9 silent]${pkgs.signal-desktop}/bin/signal-desktop''
            ''[workspace 8 silent]${pkgs.obsidian}/bin/obsidian''
            ''[workspace 10 silent]${pkgs.spotify}/bin/spotify''
            ''[workspace 8 silent]${pkgs.virt-manager}/bin/virt-manager''
            ''[workspace 10 silent]${pkgs.copyq}/bin/copyq''
            ''[workspace special silent]/run/current-system/sw/bin/protonvpn-app''
            ''[workspace special silent]${pkgs.yubioath-flutter}/bin/yubioath-flutter''
            ''[workspace special silent]${pkgs.keymapp}/bin/keymapp''
          ]
        else if config.hostSpec.isMobile then
          [
            ''${pkgs.waypaper}/bin/waypaper --restore''
            ''[workspace 9 silent]${pkgs.signal-desktop}/bin/signal-desktop''
            ''[workspace 1 silent]${pkgs.copyq}/bin/copyq''
            ''[workspace special silent]${pkgs.yubioath-flutter}/bin/yubioath-flutter''
            ''[workspace special silent]/run/current-system/sw/bin/protonvpn-app''
          ]
        else
          [
            ''${pkgs.waypaper}/bin/waypaper --restore''
          ];

      #
      # ========== Layer Rules ==========
      #
      layer = [
        #"blur, rofi"
        #"ignorezero, rofi"
        #"ignorezero, logout_dialog"

      ];
      #
      # ========== Window Rules ==========
      #
      windowrule = [
        #
        # ========== Workspace Assignments ==========
        #
        # to determine class and title for all active windows, run `hyprctl clients`
        "workspace 8, class:^(.virt-manager-wrapped)$"
        "workspace 8, class:^(obsidian)$"
        "workspace 9, class:^(brave-browser)$"
        "workspace 9, class:^(signal)$"
        "workspace 9, class:^(discord)$"
        "workspace 10, class:^(spotify)$"
        "workspace 10, class:^(CopyQ)$"
        "workspace special, title:^(Proton VPN)$"
        "workspace special, class:^(yubioath-flutter)$"
        "workspace special, class:^(keymapp)$"

        #
        # ========== Tile on launch ==========
        #
        "tile, title:^(Proton VPN)$"

        #
        # ========== Float on launch ==========
        #
        "float, class:^(galculator)$"
        "float, class:^(waypaper)$"

        # Dialog windows
        "float, title:^(Open File)(.*)$"
        "float, title:^(Select a File)(.*)$"
        "float, title:^(Choose wallpaper)(.*)$"
        "float, title:^(Open Folder)(.*)$"
        "float, title:^(Save As)(.*)$"
        "float, title:^(Library)(.*)$"
        "float, title:^(Accounts)(.*)$"
        "float, title:^(Text Import)(.*)$"
        "float, title:^(File Operation Progress)(.*)$"
        #"float, focus 0, title:^()$, class:^([Ff]irefox)"
        "float, noinitialfocus, title:^()$, class:^([Ff]irefox)"

        #
        # ========== Always opaque ==========
        #
        "opaque, class:^([Gg]imp)$"
        "opaque, class:^([Ff]lameshot)$"
        "opaque, class:^([Ii]nkscape)$"
        "opaque, class:^([Bb]lender)$"
        "opaque, class:^([Oo][Bb][Ss])$"
        "opaque, class:^([Ss]team)$"
        "opaque, class:^([Ss]team_app_*)$"
        "opaque, class:^([Vv]lc)$"
        "opaque, title:^(btop)(.*)$"
        "opaque, title:^(amdgpu_top)(.*)$"
        "opaque, title:^(Dashboard | glass*)(.*)$"
        "opaque, title:^(Live video from*)(.*)$"

        # Remove transparency from video
        "opaque, title:^(Netflix)(.*)$"
        "opaque, title:^(.*YouTube.*)$"
        "opaque, title:^(Picture-in-Picture)$"

        #
        # ========== Scratch rules ==========
        #
        #"size 80% 85%, workspace:^(special)$"
        #"center, workspace:^(special)$"

        #
        # ========== Steam rules ==========
        #
        "minsize 1 1, title:^()$,class:^([Ss]team)$"
        "immediate, class:^([Ss]team_app_*)$"
        "workspace 7, class:^([Ss]team_app_*)$"
        "monitor 0, class:^([Ss]team_app_*)$"

        #
        # ========== Fameshot rules ==========
        #
        # flameshot currently doesn't have great wayland support so needs some tweaks
        #"rounding 0, class:^([Ff]lameshot)$"
        #"noborder, class:^([Ff]lameshot)$"
        #"float, class:^([Ff]lameshot)$"
        #"move 0 0, class:^([Ff]lameshot)$"
        #"suppressevent fullscreen, class:^([Ff]lameshot)$"
        # "monitor:DP-1, ${flameshot}"
      ];

      # load at the end of the hyperland set
      # extraConfig = '''';

      #
      # ========== hy3 config ==========
      #
      #TODO enable this and config
      general.layout = "hy3";
      plugin = {
        hy3 = {
          #          autotile = {
          #            enable = true;
          #            trigger_width = 800;
          #            trigger_height = 500;
          #          };
        };
      };
    };
  };
}
