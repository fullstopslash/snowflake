# Universal settings for all hosts
{
  config,
  pkgs,
  ...
}: {
  # System-specific settings

  services = {
    fstrim.enable = true;
    system76-scheduler.enable = true;
    irqbalance.enable = true;
    journald = {
      storage = "persistent";
      rateLimitInterval = "30s";
      rateLimitBurst = 2000;
      extraConfig = ''
        SystemMaxUse=1G
      '';
    };
  };

  # Auto Tune
  services.bpftune.enable = true;
  programs.bcc.enable = true;

  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
  };

  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    #Brightness control
    ddcutil
    brightnessctl

    # nix Development tools
    nixd
    statix
    deadnix
    alejandra
    patchelf

    # Common development tools (used across multiple roles)
    gcc
    libgcc
    gnumake
    just
    stable.jujutsu

    # Common terminal tools
    jjui
    # TODO: add back in
    stable.lazyjj
    lazygit
    tree
    home-assistant-cli
    nmap
    microfetch

    #search
    silver-searcher

    #Github
    gh
    github-desktop
    gh-dash

    # Common package managers (used across multiple roles)
    mise
    uv
    yarn
    dotnet-sdk
    go

    # Common Rust toolchain (used across multiple roles)
    rustc
    rustfmt
    clippy
    cargo
    pkg-config

    # Common containers (used across multiple roles)
    distrobox
    boxbuddy
    lilipod
    podman

    # Common system utilities (used across multiple roles)
    zenity
    wget
    unzip
    spice-vdagent
    killall
    openssl
    wl-clipboard

    # Common development utilities (used across multiple roles)
    icu.dev
    marksman
    ccache
    sccache
  ];

  # Security settings
  security = {
    polkit.enable = true;
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;

    # Allow wheel group to reboot/shutdown without authentication
    polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.login1.reboot" ||
             action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
             action.id == "org.freedesktop.login1.power-off" ||
             action.id == "org.freedesktop.login1.power-off-multiple-sessions") &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  # Systemd configuration (consolidated to avoid repeated keys)
  systemd = {
    oomd.enable = true;
  };

  # SOPS secrets configuration
  sops.secrets = {
    rain-password = {
      key = "passwords/rain";
      owner = "root";
      neededForUsers = true;
    };
  };

  # User configuration
  users.users.rain = {
    hashedPasswordFile = config.sops.secrets."rain-password".path;
    isNormalUser = true;
    group = "rain";
    shell = pkgs.zsh;
    description = "rain";
    ignoreShellProgramCheck = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "adbusers"
      "video"
      "render"
      "audio"
      "i2c"
      "docker"
      "uinput"
      "dialout"
      "input"
    ];
    # packages = with pkgs; [
    # package-for-user-only
    # ];
    openssh = {
      authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSsv1OF/iAmRKdNbjAP5qf9u3qTqZXq3oBotI0hR6ea"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQ0/3qVS6Z7FA4wbhbNTKQzXxF5GcwupnYAMj9LTWsR3mvrz9Uo2yhp/sjOh37OBWyMjmLvnz1utPRtjCx2Pt3s7vT/B3aWmICcWDo3e0pbA/bCkMhSKQzcmiSO8dQCqVJOLCnOekX9JsMrr8KXjedFjFz2HpR8j6nYO7CH8nOj3inYRm2gWJkFHEENly4FOaRq+FLBZcskD1k0EQ5ABH8XPpzcS/YCuRqtqGEF4Cq5/k8oSO98Hx1drABokh0C4SLTFhTcLIj9OOKAoKgrWUk/Skf1wsoCctZllIsrIfaC8CkFuMvAIn0+Rm8KBNc4UZjssjSR7lU28gx0fEBaoc++LN80B70LKK17Wlf9I3QGrf4YcLmepcmNXNvGWF6dn2+C5dn4d92P+quz28L2NwvLro+4wsgtaEu2mfPsaOpAP3Ulu422qi8CcRn8hgz3QGYRn51fardcA9UxE3YcGHjUCKfxvwYTqiubA1XtPfXrjo8t0xFhKKzSuC1ckNw0lGn6C0BJRFXZG4OeDzqwAbpwTQDhF4Ss4xBLdWfKos8vonapz9rpADzkMUqhbN6oAEcTUciYPc4JRvd0UuEOZWDV2qjTyl0hfywiiwgD6AeO59ahCyD2uPrlml6aeBLrKkxlqtNtlakOZR7iJH3pPD48AJrMXRuZymD+OG+AELPqQ=="
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1E5omJkBoYqdLgjNu9x5XSCAJzX8PHXBb08RYmh3DHmH2sF5Ece6rXi+UX/UiuUr0ez9032CGYaaOnyFtqfhj8PPNZnIKLukJ+jTrTARyiS1+AJC4n8Fl9ju87jLzW5cQlLGc2uTVL8dSGLPDbdAaALmJmJMmACBGRm8ekjz9lHP+PrXeQFRYZYDbD+B7aF5QRswRVtF2VSEZuPZfWcRlyN1BCa+fgF1w5c7X7gxQS2rNMemFRw29Y+cG1x3V9l4BS4wAVjXLcUI98CQ44v1RbQ9k1jAHFXT05oYhcLxbX0WySWURkZXMXopp8mzR7w/o+W/HfMzUl0jvuFuJVVtUYCBMnkvsC1Clhte3YmHhZrajgZ4LQW3sgWPUDcogPl40itBUsAC6KkfZ4cIzb2QDAdUZrTFiswYGWhuexekpGnjxoKI6ti05/k4ZAQduY03O5xr20pdUC6qWin8Q31yGKs1wt0D18oSrojwZgAiJ5VcVlz7P9fovvHo7O4xfSzs="
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEp/Qb34n+5RN1IzDq/IqgHKwn0GjPRLN8luzFd66K+1plgHHRbu8BZLHIDbt6mWdGecFNzCbL6EE0dlAnIz5TTceaxRWP/JwKg3gFFpXPn3cDtkJYKwIDbNTzdc0Kfk4MDDNWuEpkShrCGFw44SrOvny4sJX50TZy9PNXAcsqGEgop6rQTwYNZufmYwoy+HO/WDOqYfHDs+D4MDqlM2zXgQflKxn2Pptcd/y3rNef9+kCAGWVHYyfXhIVRvUBPbtdCf7tJrI2Lt3ah6DRmAO0rrh8rH7Yh1w7SD/Ggskz1SB5iPDNN2vcVhP9o1l9peDv6K/w8HPEZTZqgbuX/1c3JS3O7DXaP6iOFXWf8Hg5YgyLZRNhtbvsGLW2iul9gR6Ag1YLpZppKSGUf6b3vWughVyrm8auuFFZMxH9Lgg422HB3vWImZoPHy7kzMnHcpvG50b312bl/jVC54+quON1XOpUN4PqwoO2qokvuA/4X7DIzpAHMjJxPc9UgzGpkss= openpgp:0x0F4E55A5"
      ];
    };
  };

  # Primary group for user rain
  users.groups.rain = {};

  # Enable user lingering for reliable user service startup
  # This ensures user services can start even if graphical session hasn't fully initialized
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/rain 0644 root root - -"
  ];

  # Non-gaming global env vars can live here; gaming vars moved to gaming role

  # Boot settings (consolidated to avoid repeated keys)
  boot = {
    # Conservative sysctl tuning
    kernel.sysctl = {
      "kernel.sched_autogroup_enabled" = 1;
      "vm.swappiness" = 10;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 20;
      # Networking throughput
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # TCP Fast Open (enable client and server)
      "net.ipv4.tcp_fastopen" = 3;
      # Increase socket buffers for high-throughput WAN
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.core.rmem_default" = 134217728;
      "net.core.wmem_default" = 134217728;
    };

    # Faster boot and early KMS
    initrd = {
      systemd.enable = true;
      kernelModules = ["amdgpu"];
    };

    # Put /tmp in RAM for faster temp I/O
    tmp = {
      useTmpfs = true;
      # Also put /var/tmp in RAM (may affect very large temp files)
      tmpfsSize = "75%";
    };
  };

  # CPU microcode
  hardware.cpu.amd.updateMicrocode = true;

  # Nix settings
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = false;
      max-jobs = 12;  # Parallel derivation builds
      max-substitution-jobs = 1;  # Force sequential cache checking to honor priority
      download-buffer-size = 524288000;
      cores = 0;  # 0 = use all available cores per build
      http-connections = 50;
      connect-timeout = 5;
      timeout = 0;
      trusted-users = ["root" "rain"];
    };

    # Garbage collection
    gc = {
      dates = "daily";
      options = "--delete-older-than 10d";
    };
  };

  # Consolidate environment.* keys to avoid repeats flagged by statix
  # environment = {
  #   variables = {
  #     CC = "${pkgs.ccacheWrapper}/bin/cc";
  #     CXX = "${pkgs.ccacheWrapper}/bin/c++";
  #     RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
  #     CCACHE_DIR = "/home/rain/.cache/ccache";
  #     SCCACHE_DIR = "/home/rain/.cache/sccache";
  #     CCACHE_MAXSIZE = "15G";
  #     SCCACHE_CACHE_SIZE = "30G";
  #     # Keep existing variables below; gaming env lives in gaming role
  #   };
  #
  #   # KWallet settings are configured in the Plasma role
  # };

  # Ensure cache directories exist
  # systemd.tmpfiles.rules = [
  #   "d /var/cache/ccache 0755 root root -"
  #   "d /var/cache/sccache 0755 root root -"
  # ];

  # Programs
  programs = {
    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 17d --keep 8";
      flake = "/home/rain/nix/";
    };

    nix-ld.enable = true;
    # nix-ld.libraries = with pkgs; [
    #   # Add any missing dynamic libraries for unpatched programs here
    # ];

    # KDE wallet configuration for auto-unlock
    kdeconnect.enable = true;
  };

  # KDE wallet configuration for auto-unlock (moved into environment.etc above)

  # Time zone
  time.timeZone = "America/Chicago";

  # Locale settings
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Auto upgrade settings
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "02:00";
  };

  # Systemd configuration (continued)
  systemd = {
    slices."nix-daemon".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "95%";
    };
    services."nix-daemon" = {
      serviceConfig = {
        Slice = "nix-daemon.slice";
        OOMScoreAdjust = 1000;
      };
    };
    user.services = {};
  };

  # Power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  systemd.services."system76-power-performance" = {
    description = "Set System76 power profile to performance";
    after = ["system76-power.service" "multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.system76-power}/bin/system76-power profile performance";
    };
  };

  # NVMe queue tuning via udev (scheduler none, modest readahead)
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none", ATTR{queue/read_ahead_kb}="256"
  '';

  # fileSystems additions
  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["mode=1777" "size=75%"];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
