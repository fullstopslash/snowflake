#NOTE: This ISO is NOT minimal. We don't want a minimal environment when using the iso for recovery purposes.
{
  inputs,
  outputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  # ISO doesn't import hosts/common/core, but needs overlays for pkgs.unstable
  nixpkgs.overlays = [ outputs.overlays.default ];

  # Disable wireless to avoid conflict with NetworkManager from modules/services/networking
  networking.wireless.enable = lib.mkForce false;

  imports = lib.flatten [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    #"${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    # This is overkill but I want my core home level utils if I need to use the iso environment for recovery purpose
    inputs.home-manager.nixosModules.home-manager
    (map lib.custom.relativeToRoot [
      # FIXME: Switch this to just import hosts/common/core (though have to be careful to purposefully not add platform file..
      "hosts/common/optional/minimal-user.nix"
      "hosts/common/core/keyd.nix" # FIXME: Remove if we move to hosts/common/core above
      "modules/common/host-spec.nix"
    ])
    # FIXME: Dynamic user import causes infinite recursion - disabled
    # (
    #   let
    #     path = lib.custom.relativeToRoot "hosts/common/users/${config.hostSpec.primaryUsername}/default.nix";
    #   in
    #     lib.optional (lib.pathExists path) path
    # )
  ];

  hostSpec = {
    hostName = "iso";
    primaryUsername = "rain";
    isProduction = lib.mkForce false;
    hasSecrets = false; # ISO doesn't have sops secrets configured

    # Needed because we don't use hosts/common/core for iso
    inherit (inputs.nix-secrets)
      domain
      networking
      ;

    #TODO(git): This is stuff for home/${config.hostSpec.primaryUsername}/common/core/git.nix. should create home/${config.hostSpec.primaryUsername}/common/optional/development.nix so core git.nix doesn't use it.
    handle = "rain";
    email.gitHub = inputs.nix-secrets.email.gitHub;
  };

  # root's ssh key are mainly used for remote deployment
  users.extraUsers.root = {
    inherit (config.users.users.${config.hostSpec.username}) hashedPassword;
    openssh.authorizedKeys.keys = [
      inputs.nix-secrets.bootstrap.sshPublicKey
    ]
    ++ config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys or [ ];
  };

  # Also add SSH key to the regular user for bootstrap
  users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys = [
    inputs.nix-secrets.bootstrap.sshPublicKey
  ];

  environment.etc = {
    isoBuildTime = {
      text = lib.readFile "${pkgs.runCommand "timestamp" {
        # builtins.currentTime requires --impure
        env.when = builtins.currentTime;
      } "echo -n `date -d @$when  +%Y-%m-%d_%H-%M-%S` > $out"}";
    };
    # Pre-populate bash history with useful commands (most recent = first up-arrow)
    # NOTE: For full install, run from HOST: ./scripts/bootstrap-nixos.sh -n <hostname> -d <ip>
    "skel/.bash_history" = {
      text = ''
        cat /etc/nix-config/nixos-installer/README.md
        lsblk
        ip a
        sudo nixos-install --flake /etc/nix-config#griefling --no-root-passwd
        sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode disko /etc/nix-config/hosts/common/disks/btrfs-disk.nix --arg disk '"/dev/vda"' --arg withSwap true --argstr swapSize 8
      '';
    };
    # Pre-clone nix-config repo into ISO for offline installation
    "nix-config".source = lib.cleanSource ../../..;
  };

  # Ensure root gets the pre-populated bash history
  systemd.tmpfiles.rules = [
    "C /root/.bash_history 0600 root root - /etc/skel/.bash_history"
  ];

  # Copy bash history to primary user after home directory exists
  systemd.services.setup-user-bash-history = {
    description = "Setup bash history for primary user";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      USER_HOME="/home/${config.hostSpec.username}"
      if [ -d "$USER_HOME" ] && [ ! -f "$USER_HOME/.bash_history" ]; then
        cp /etc/skel/.bash_history "$USER_HOME/.bash_history"
        chown ${config.hostSpec.username}:users "$USER_HOME/.bash_history"
        chmod 600 "$USER_HOME/.bash_history"
      fi
    '';
  };

  # Add the build time to the prompt so it's easier to know the ISO age
  programs.bash.promptInit = ''
    export PS1="\\[\\033[01;32m\\]\\u@\\h-$(cat /etc/isoBuildTime)\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "
  '';

  # The default compression-level is (6) and takes too long on some machines (>30m). 3 takes <2m
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    config.allowUnfree = true;
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    extraOptions = "experimental-features = nix-command flakes";
  };

  # Passwordless sudo for bootstrap
  security.sudo.wheelNeedsPassword = false;

  services = {
    qemuGuest.enable = true;
    openssh = {
      ports = [ config.hostSpec.networking.ports.tcp.ssh ];
      settings = {
        PermitRootLogin = lib.mkForce "prohibit-password"; # SSH key auth only
        PasswordAuthentication = false; # Disable password auth
      };
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "vfat"
    ];
  };

  networking = {
    hostName = "iso";
  };

  systemd = {
    services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
    # gnome power settings to not turn off screen
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
