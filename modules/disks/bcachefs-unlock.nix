# Bcachefs native encryption unlock module
#
# Provides automatic boot unlock for bcachefs encrypted partitions using:
# - Primary: systemd-ask-password for interactive unlock
# - Optional: Clevis for TPM/Tang automated unlock with fallback
#
# Based on nixpkgs bcachefs.nix module design and FINDINGS from Phase 20-01.
#
# Boot workflow (handled by nixpkgs bcachefs.nix module):
#   1. initrd systemd detects encrypted bcachefs filesystems
#   2. Auto-generates unlock-bcachefs-* services for each filesystem
#   3. If Clevis enabled: attempts clevis decrypt < /etc/clevis/${device}.jwe | bcachefs unlock
#   4. Falls back to systemd-ask-password interactive prompt on failure
#   5. Unlocks device via kernel keyring and allows mount to proceed
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disks;
  hostCfg = config.host;

  # SOPS folder path
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";

  # Check if layout uses bcachefs native encryption
  isEncrypted = lib.strings.hasInfix "bcachefs-encrypt" cfg.layout;

  # TPM unlock configuration
  tpmEnabled = hostCfg.encryption.tpm.enable or false;
  pcrIds = hostCfg.encryption.tpm.pcrIds or "7";

  # Remote SSH unlock configuration
  remoteUnlockPort = 2222; # Default port for initrd SSH

  # Get authorized keys from primary user's yubikey public keys
  primaryUserKeysPath = lib.custom.relativeToRoot "modules/users/${hostCfg.primaryUsername}/keys/";
  authorizedKeys =
    if builtins.pathExists primaryUserKeysPath then
      lib.lists.forEach (lib.filesystem.listFilesRecursive primaryUserKeysPath) (
        key: builtins.readFile key
      )
    else
      [ ];

  # Clevis JWE token paths
  # Token stored in nix-secrets for build-time access (pathExists works with Nix store paths)
  clevisTokenSource = "${sopsFolder}/clevis/bcachefs-root.jwe";
  clevisTokenPersist = "${hostCfg.persistFolder}/etc/clevis/bcachefs-root.jwe";

  # Initrd SSH host key paths
  # Pre-generated and stored in nix-secrets for nixos-anywhere deployment
  initrdSshKeySource = "${builtins.toString inputs.nix-secrets}/ssh/initrd/${hostCfg.hostName}_initrd_ed25519";
  initrdSshKeyPersist = "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key";

  # Get filesystem device paths for Clevis configuration
  # nixpkgs bcachefs module checks if firstDevice(fs) exists in boot.initrd.clevis.devices
  rootDevice = config.fileSystems."/".device or null;
  persistDevice = config.fileSystems."/persist".device or null;
in
{
  config = lib.mkIf (cfg.enable && isEncrypted) {
    # Enable bcachefs filesystem support
    boot.supportedFilesystems = [ "bcachefs" ];

    # Ensure required kernel modules are available
    boot.initrd.availableKernelModules = [
      "bcachefs"
      "sha256"
      # ChaCha20/Poly1305 built-in for kernels >= 6.15
      # For older kernels, add: "poly1305" "chacha20"
      "tpm_crb" # Critical for TPM support
      # Network drivers for remote unlock
      "r8169" # Realtek Ethernet
      "e1000e" # Intel Ethernet
      "igb" # Intel Gigabit
    ];

    # Use systemd in initrd (required for Clevis integration)
    boot.initrd.systemd = {
      enable = true;

      # Configure DHCP for remote unlock
      network = {
        enable = true;
        networks."10-ethernet" = {
          matchConfig.Name = "en*";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
          };
          dhcpV4Config.RouteMetric = 1024;
        };
      };

      # SSH access in initrd for remote unlock
      services.sshd = {
        description = "SSH Daemon for remote unlock";
        wantedBy = [ "initrd.target" ];
        after = [ "initrd-nixos-copy-secrets.service" ];
        before = [ "initrd-switch-root.target" ];
        conflicts = [ "initrd-switch-root.target" ];
        unitConfig.DefaultDependencies = false;

        serviceConfig = {
          ExecStart = "${pkgs.openssh}/bin/sshd -D -e -f /etc/ssh/sshd_config.d/initrd.conf";
          KillMode = "process";
          Restart = "always";
        };
      };

      # Copy SSH config and Clevis tokens into initrd
      contents = {
        "/etc/ssh/sshd_config.d/initrd.conf".text = ''
          Port ${toString remoteUnlockPort}
          PermitRootLogin yes
          AuthorizedKeysFile /etc/ssh/authorized_keys.d/root
          HostKey /etc/ssh/initrd_ssh_host_ed25519_key
        '';
        "/etc/ssh/authorized_keys.d/root".text = lib.concatStringsSep "\n" authorizedKeys;
      } // lib.optionalAttrs (builtins.pathExists initrdSshKeySource) {
        # Copy pre-generated initrd SSH host key from nix-secrets
        "/etc/ssh/initrd_ssh_host_ed25519_key".source = initrdSshKeySource;
      } // lib.optionalAttrs (tpmEnabled && rootDevice != null && builtins.pathExists clevisTokenSource) {
        # Copy Clevis token to initrd at the path nixpkgs bcachefs module expects
        # Path format: /etc/clevis/${device}.jwe where device is the filesystem device path
        "/etc/clevis/${rootDevice}.jwe".source = clevisTokenSource;
      } // lib.optionalAttrs (tpmEnabled && persistDevice != null && persistDevice != rootDevice && builtins.pathExists clevisTokenSource) {
        # Persist filesystem token (if different device than root)
        "/etc/clevis/${persistDevice}.jwe".source = clevisTokenSource;
      };

      storePaths = [
        "${pkgs.openssh}/bin/sshd"
      ] ++ lib.optionals tpmEnabled [
        "${pkgs.clevis}"
        "${pkgs.jose}"
      ];

      # Include clevis/jose packages for TPM unlock
      packages = lib.optionals tpmEnabled [
        pkgs.clevis
        pkgs.jose
      ];
    };

    # Enable Clevis for automated TPM unlock
    # Note: boot.initrd.clevis is primarily for LUKS, but nixpkgs bcachefs module
    # checks for clevis.enable and device presence to trigger clevis unlock
    boot.initrd.clevis = lib.mkIf (tpmEnabled && rootDevice != null) {
      enable = true;
      # Device entries must match filesystem device paths exactly
      # The bcachefs module checks: hasAttr (firstDevice fs) config.boot.initrd.clevis.devices
      # secretFile is required by clevis module (for LUKS), but bcachefs looks for
      # tokens at /etc/clevis/${device}.jwe which we provide via contents above
      # Only set devices if token file exists (build-time check using nix-secrets path)
      devices = lib.optionalAttrs (builtins.pathExists clevisTokenSource) {
        ${rootDevice}.secretFile = clevisTokenSource;
      } // lib.optionalAttrs (persistDevice != null && persistDevice != rootDevice && builtins.pathExists clevisTokenSource) {
        ${persistDevice}.secretFile = clevisTokenSource;
      };
    };

    # Make clevis available in running system for token generation
    environment.systemPackages = lib.optionals tpmEnabled [
      pkgs.clevis
      pkgs.jose
    ];

    # Documentation for users
    warnings =
      lib.optionals isEncrypted [
        ''
          Bcachefs native encryption is enabled for ${cfg.layout}.

          Boot unlock behavior:
          ${
            if tpmEnabled then
              ''
                - TPM2 automatic unlock via Clevis (enabled)
                - Fallback to interactive passphrase prompt
              ''
            else
              "- Interactive passphrase prompt via systemd-ask-password"
          }
          - Remote SSH unlock in initrd (enabled on port ${toString remoteUnlockPort})

          ${
            if !tpmEnabled then
              ''
                To enable TPM unlock, add to your host configuration:
                  host.encryption.tpm.enable = true;

                After enabling, generate Clevis token:
                  sudo just bcachefs-setup-tpm
              ''
            else if !builtins.pathExists clevisTokenPersist then
              ''
                TPM unlock is enabled but token not found.
                Generate Clevis token:
                  sudo just bcachefs-setup-tpm

                Token location: ${clevisTokenPersist}
              ''
            else
              ''
                TPM unlock is configured.
                Token location: ${clevisTokenPersist}
                Clevis will attempt automatic unlock, with fallback to interactive prompt.
              ''
          }

          Remote unlock setup:
          - SSH into initrd: ssh -p ${toString remoteUnlockPort} root@<host-ip>
          - Password prompt will appear automatically
          - Authorized keys: primary user's yubikey keys

          Security note:
          - ChaCha20/Poly1305 AEAD provides authenticated encryption
          - Tamper detection and replay protection included
          - TPM binding to PCR ${pcrIds} (Secure Boot state)

          See docs/bcachefs.md for detailed encryption workflows.
        ''
      ]
      ++ lib.optionals (tpmEnabled && hostCfg.persistFolder == "") [
        ''
          WARNING: TPM unlock requires persistFolder to be set for token storage.
          Set host.persistFolder in your host configuration.
        ''
      ];
  };
}
