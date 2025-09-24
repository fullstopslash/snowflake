{
  pkgs,
  lib,
  ...
}: let
  # Snapshot this repository into the store and link it into the live ISO
  repoSrc = pkgs.nix-gitignore.gitignoreSource [] (../.);
in {
  # Minimal installer ISO config: SSH + essentials + NetworkManager + serial console
  services.getty.autologinUser = "nixos";
  services.openssh = {
    enable = true;
    # Ensure sshd starts immediately and is reachable on the installer ISO
    startWhenNeeded = false;
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  nixpkgs.hostPlatform = "x86_64-linux";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSsv1OF/iAmRKdNbjAP5qf9u3qTqZXq3oBotI0hR6ea"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQ0/3qVS6Z7FA4wbhbNTKQzXxF5GcwupnYAMj9LTWsR3mvrz9Uo2yhp/sjOh37OBWyMjmLvnz1utPRtjCx2Pt3s7vT/B3aWmICcWDo3e0pbA/bCkMhSKQzcmiSO8dQCqVJOLCnOekX9JsMrr8KXjedFjFz2HpR8j6nYO7CH8nOj3inYRm2gWJkFHEENly4FOaRq+FLBZcskD1k0EQ5ABH8XPpzcS/YCuRqtqGEF4Cq5/k8oSO98Hx1drABokh0C4SLTFhTcLIj9OOKAoKgrWUk/Skf1wsoCctZllIsrIfaC8CkFuMvAIn0+Rm8KBNc4UZjssjSR7lU28gx0fEBaoc++LN80B70LKK17Wlf9I3QGrf4YcLmepcmNXNvGWF6dn2+C5dn4d92P+quz28L2NwvLro+4wsgtaEu2mfPsaOpAP3Ulu422qi8CcRn8hgz3QGYRn51fardcA9UxE3YcGHjUCKfxvwYTqiubA1XtPfXrjo8t0xFhKKzSuC1ckNw0lGn6C0BJRFXZG4OeDzqwAbpwTQDhF4Ss4xBLdWfKos8vonapz9rpADzkMUqhbN6oAEcTUciYPc4JRvd0UuEOZWDV2qjTyl0hfywiiwgD6AeO59ahCyD2uPrlml6aeBLrKkxlqtNtlakOZR7iJH3pPD48AJrMXRuZymD+OG+AELPqQ=="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1E5omJkBoYqdLgjNu9x5XSCAJzX8PHXBb08RYmh3DHmH2sF5Ece6rXi+UX/UiuUr0ez9032CGYaaOnyFtqfhj8PPNZnIKLukJ+jTrTARyiS1+AJC4n8Fl9ju87jLzW5cQlLGc2uTVL8dSGLPDbdAaALmJmJMmACBGRm8ekjz9lHP+PrXeQFRYZYDbD+B7aF5QRswRVtF2VSEZuPZfWcRlyN1BCa+fgF1w5c7X7gxQS2rNMemFRw29Y+cG1x3V9l4BS4wAVjXLcUI98CQ44v1RbQ9k1jAHFXT05oYhcLxbX0WySWURkZXMXopp8mzR7w/o+W/HfMzUl0jvuFuJVVtUYCBMnkvsC1Clhte3YmHhZrajgZ4LQW3sgWPUDcogPl40itBUsAC6KkfZ4cIzb2QDAdUZrTFiswYGWhuexekpGnjxoKI6ti05/k4ZAQduY03O5xr20pdUC6qWin8Q31yGKs1wt0D18oSrojwZgAiJ5VcVlz7P9fovvHo7O4xfSzs="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEp/Qb34n+5RN1IzDq/IqgHKwn0GjPRLN8luzFd66K+1plgHHRbu8BZLHIDbt6mWdGecFNzCbL6EE0dlAnIz5TTceaxRWP/JwKg3gFFpXPn3cDtkJYKwIDbNTzdc0Kfk4MDDNWuEpkShrCGFw44SrOvny4sJX50TZy9PNXAcsqGEgop6rQTwYNZufmYwoy+HO/WDOqYfHDs+D4MDqlM2zXgQflKxn2Pptcd/y3rNef9+kCAGWVHYyfXhIVRvUBPbtdCf7tJrI2Lt3ah6DRmAO0rrh8rH7Yh1w7SD/Ggskz1SB5iPDNN2vcVhP9o1l9peDv6K/w8HPEZTZqgbuX/1c3JS3O7DXaP6iOFXWf8Hg5YgyLZRNhtbvsGLW2iul9gR6Ag1YLpZppKSGUf6b3vWughVyrm8auuFFZMxH9Lgg422HB3vWImZoPHy7kzMnHcpvG50b312bl/jVC54+quON1XOpUN4PqwoO2qokvuA/4X7DIzpAHMjJxPc9UgzGpkss= openpgp:0x0F4E55A5"
  ];

  users.users.nixos = {
    isNormalUser = true;
    description = "Live User";
    extraGroups = ["wheel" "networkmanager"];
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSsv1OF/iAmRKdNbjAP5qf9u3qTqZXq3oBotI0hR6ea"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQ0/3qVS6Z7FA4wbhbNTKQzXxF5GcwupnYAMj9LTWsR3mvrz9Uo2yhp/sjOh37OBWyMjmLvnz1utPRtjCx2Pt3s7vT/B3aWmICcWDo3e0pbA/bCkMhSKQzcmiSO8dQCqVJOLCnOekX9JsMrr8KXjedFjFz2HpR8j6nYO7CH8nOj3inYRm2gWJkFHEENly4FOaRq+FLBZcskD1k0EQ5ABH8XPpzcS/YCuRqtqGEF4Cq5/k8oSO98Hx1drABokh0C4SLTFhTcLIj9OOKAoKgrWUk/Skf1wsoCctZllIsrIfaC8CkFuMvAIn0+Rm8KBNc4UZjssjSR7lU28gx0fEBaoc++LN80B70LKK17Wlf9I3QGrf4YcLmepcmNXNvGWF6dn2+C5dn4d92P+quz28L2NwvLro+4wsgtaEu2mfPsaOpAP3Ulu422qi8CcRn8hgz3QGYRn51fardcA9UxE3YcGHjUCKfxvwYTqiubA1XtPfXrjo8t0xFhKKzSuC1ckNw0lGn6C0BJRFXZG4OeDzqwAbpwTQDhF4Ss4xBLdWfKos8vonapz9rpADzkMUqhbN6oAEcTUciYPc4JRvd0UuEOZWDV2qjTyl0hfywiiwgD6AeO59ahCyD2uPrlml6aeBLrKkxlqtNtlakOZR7iJH3pPD48AJrMXRuZymD+OG+AELPqQ=="
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1E5omJkBoYqdLgjNu9x5XSCAJzX8PHXBb08RYmh3DHmH2sF5Ece6rXi+UX/UiuUr0ez9032CGYaaOnyFtqfhj8PPNZnIKLukJ+jTrTARyiS1+AJC4n8Fl9ju87jLzW5cQlLGc2uTVL8dSGLPDbdAaALmJmJMmACBGRm8ekjz9lHP+PrXeQFRYZYDbD+B7aF5QRswRVtF2VSEZuPZfWcRlyN1BCa+fgF1w5c7X7gxQS2rNMemFRw29Y+cG1x3V9l4BS4wAVjXLcUI98CQ44v1RbQ9k1jAHFXT05oYhcLxbX0WySWURkZXMXopp8mzR7w/o+W/HfMzUl0jvuFuJVVtUYCBMnkvsC1Clhte3YmHhZrajgZ4LQW3sgWPUDcogPl40itBUsAC6KkfZ4cIzb2QDAdUZrTFiswYGWhuexekpGnjxoKI6ti05/k4ZAQduY03O5xr20pdUC6qWin8Q31yGKs1wt0D18oSrojwZgAiJ5VcVlz7P9fovvHo7O4xfSzs="
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEp/Qb34n+5RN1IzDq/IqgHKwn0GjPRLN8luzFd66K+1plgHHRbu8BZLHIDbt6mWdGecFNzCbL6EE0dlAnIz5TTceaxRWP/JwKg3gFFpXPn3cDtkJYKwIDbNTzdc0Kfk4MDDNWuEpkShrCGFw44SrOvny4sJX50TZy9PNXAcsqGEgop6rQTwYNZufmYwoy+HO/WDOqYfHDs+D4MDqlM2zXgQflKxn2Pptcd/y3rNef9+kCAGWVHYyfXhIVRvUBPbtdCf7tJrI2Lt3ah6DRmAO0rrh8rH7Yh1w7SD/Ggskz1SB5iPDNN2vcVhP9o1l9peDv6K/w8HPEZTZqgbuX/1c3JS3O7DXaP6iOFXWf8Hg5YgyLZRNhtbvsGLW2iul9gR6Ag1YLpZppKSGUf6b3vWughVyrm8auuFFZMxH9Lgg422HB3vWImZoPHy7kzMnHcpvG50b312bl/jVC54+quON1XOpUN4PqwoO2qokvuA/4X7DIzpAHMjJxPc9UgzGpkss= openpgp:0x0F4E55A5"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [22];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 15d --keep 8";
    flake = "/home/nixos/nix"; # sets NH_OS_FLAKE variable for you
  };

  environment = {
    systemPackages = with pkgs; [
      git
      curl
      age
      sops
      nh
      btop
      neovim
      networkmanager
      iw
      rsync
      wirelesstools
    ];

    # Convenience aliases and a small helper for quick deployments
    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      na = "nix run github:nix-community/nixos-anywhere --";
    };

    interactiveShellInit = ''
      # Seed history with vmtest install command
      HISTFILE="$HOME/.bash_history"
      mkdir -p "$(dirname "$HISTFILE")"
      if ! grep -q '^nh os switch -u -H vmtest$' "$HISTFILE" 2>/dev/null; then
        printf '%s\n' 'nh os switch -u -H vmtest' >> "$HISTFILE"
        chmod 600 "$HISTFILE" || true
      fi

      # Seed history with disko install command for vmtest (explicit mountpoint /mnt)
      if ! grep -q '^sudo nix run github:nix-community/disko -- --mode disko /home/nixos/nix/hosts/vmtest/disko-config.nix$' "$HISTFILE" 2>/dev/null; then
        printf '%s\n' 'sudo nix run github:nix-community/disko -- --mode disko /home/nixos/nix/hosts/vmtest/disko-config.nix' >> "$HISTFILE"
        chmod 600 "$HISTFILE" || true
      fi

      deploy() {
        if [ "$#" -lt 1 ]; then
          printf "%s\n" "usage: deploy <host>" >&2
          return 2
        fi
        nix run github:nix-community/nixos-anywhere -- --flake ".#$1"
      }

      install_host() {
        if [ "$#" -lt 1 ]; then
          printf "%s\n" "usage: install_host <host>" >&2
          return 2
        fi
        HOST="$1"
        printf '%s\n' "[1/2] Disko partitioning for $HOST (mounting to /mnt)..."
        sudo nix run github:nix-community/disko -- \
          --mode disko \
          "/home/nixos/nix/hosts/$HOST/disko-config.nix" || return $?

        printf '%s\n' "[2/2] nixos-install for $HOST..."
        sudo nixos-install --no-root-passwd --flake "/home/nixos/nix#$HOST"
      }
    '';
  };

  # Avoid boot stalls in some environments
  systemd.services."NetworkManager-wait-online".enable = false;
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
    "nomodeset"
  ];

  # Reduce boot menu timeout (override ISO default)
  boot.loader.timeout = lib.mkForce 1;

  console = {
    earlySetup = true;
    useXkbConfig = true;
  };

  # Place a symlink so the flake is available at /home/nixos/nix on the ISO
  systemd.tmpfiles.rules = [
    "L+ /home/nixos/nix - - - - ${repoSrc}"
  ];
}
