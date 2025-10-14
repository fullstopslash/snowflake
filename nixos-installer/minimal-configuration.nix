{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot [
      "modules/common/host-spec.nix"
      "hosts/common/core/ssh.nix"
      "hosts/common/users"
      "hosts/common/optional/minimal-user.nix"
    ])
  ];

  hostSpec = {
    isMinimal = lib.mkForce true;
    hostName = "installer";
    username = lib.mkDefault "ta";
    primaryUsername = lib.mkDefault "ta";
  };

  fileSystems."/boot".options = [ "umask=0077" ]; # Removes permissions and security warnings.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot = {
    enable = true;
    # we use Git for version control, so we don't need to keep too many generations.
    configurationLimit = lib.mkDefault 3;
    # pick the highest resolution for systemd-boot's console.
    consoleMode = lib.mkDefault "max";
  };
  boot.initrd = {
    systemd.enable = true;
    systemd.emergencyAccess = true; # Don't need to enter password in emergency mode
    luks.forceLuksSupportInInitrd = true;
  };
  boot.kernelParams = [
    "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
    "systemd.show_status=true"
    #"systemd.log_level=debug"
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];

  # allow sudo over ssh with yubikey
  security.pam = {
    rssh.enable = true;
    services.sudo = {
      rssh = true;
      u2fAuth = true;
    };
  };

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      wget
      curl
      rsync
      git
      ;
  };

  networking = {
    networkmanager.enable = true;
  };

  # Passwordless sudo for wheel group during bootstrap
  security.sudo.wheelNeedsPassword = false;

  services = {
    qemuGuest.enable = true;
    openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        PermitRootLogin = "prohibit-password"; # Only allow SSH key auth for root
        PasswordAuthentication = false; # Disable password auth entirely
      };
      authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
    };
  };

  # Add your SSH public keys here for initial ISO access
  # This allows the bootstrap script to connect before nixos-anywhere runs
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSsv1OF/iAmRKdNbjAP5qf9u3qTqZXq3oBotI0hR6ea"
  ];
  users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys = 
    config.users.users.root.openssh.authorizedKeys.keys;

  nix = {
    #FIXME(installer): registry and nixPath shouldn't be required here because flakes but removal results in warning spam on build
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  system.stateVersion = "24.11";
}
