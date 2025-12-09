# Adding A New Host

[README](../README.md) > Adding A New Host

## Quick Start (< 10 minutes)

For new hosts using the role-based system, adding a machine is streamlined:

### 1. Create minimal host definition

```bash
mkdir -p hosts/nixos/<hostname>
```

Create `hosts/nixos/<hostname>/default.nix`:

```nix
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Choose a role: desktop, laptop, server, vm
  roles.laptop = true;

  hostSpec = {
    hostName = "<hostname>";
    username = "rain";  # your username
    # Override any role defaults here
  };
}
```

### 2. Add to flake.nix

Add to `nixosConfigurations`:

```nix
<hostname> = mkHost {
  hostname = "<hostname>";
  system = "x86_64-linux";
};
```

### 3. Bootstrap with nixos-anywhere

From your main machine:

```bash
./scripts/bootstrap-nixos.sh \
  -n <hostname> \
  -d <ip-or-hostname> \
  -k ~/.ssh/your_key
```

The script handles:
- nixos-anywhere installation
- SSH host key generation
- Age key derivation and nix-secrets update
- User age key creation
- Copying nix-config to target
- Initial rebuild

### 4. Verify secrets

After bootstrap, on the new host:

```bash
./scripts/check-sops.sh --verbose
```

## Role System

Roles automatically configure:
- Software packages and services
- hostSpec defaults (wayland, window manager, etc.)
- Secret categories (which secrets are available)

| Role | Secret Categories | Use Case |
|------|------------------|----------|
| desktop | base, desktop, network | Workstations with GUI |
| laptop | base, desktop, network | Mobile workstations |
| server | base, server, network | Headless servers |
| vm | base | Testing/minimal |

## Secret Categories

Secrets are organized by purpose:

| Category | Secrets | File |
|----------|---------|------|
| base | user password, age key, msmtp | base.nix |
| desktop | Home Assistant tokens | desktop.nix |
| server | borg backup, service creds | server.nix |
| network | tailscale OAuth | network.nix |
| shared | cross-host secrets | shared.nix (via shared.yaml) |

## Manual Bootstrap (if not using script)

If you prefer manual setup:

### Generate and register host age key

1. On the new host, generate SSH host key:
   ```bash
   sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
   ```

2. Convert to age key:
   ```bash
   cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
   ```

3. In nix-secrets, add to `.sops.yaml`:
   ```yaml
   keys:
     hosts:
       - &<hostname> age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

   creation_rules:
     - path_regex: <hostname>\.yaml$
       key_groups:
         - age:
           - *<hostname>
           - *rain_<hostname>  # user key, if exists
   ```

4. Create empty host secrets file:
   ```bash
   echo '{}' > sops/<hostname>.yaml
   sops -e -i sops/<hostname>.yaml
   ```

5. Add host to shared.yaml creation rule (for shared secrets access)

6. Rekey all secrets:
   ```bash
   just rekey
   ```

### Generate user age key

The bootstrap script handles this, but manually:

```bash
# Generate key
age-keygen -o /tmp/age-key.txt

# Add public key to .sops.yaml as rain_<hostname>
# Add private key to sops/<hostname>.yaml as keys/age
```

### First rebuild

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## Troubleshooting

### "SOPS: Host secrets file not found"

The host's secrets file doesn't exist in nix-secrets. Either:
- Run the bootstrap script to create it
- Manually create `nix-secrets/sops/<hostname>.yaml`
- Set `hostSpec.hasSecrets = false` if this host shouldn't have secrets

### "Failed to decrypt"

The host's age key isn't in the sops creation rules:
1. Get the host's age key: `cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age`
2. Add to `.sops.yaml`
3. Rekey: `just rekey`
4. Update flake: `nix flake update nix-secrets`

### Age key not created

sops-nix creates `~/.config/sops/age/keys.txt` from `keys/age` in the host's secrets file.
Verify the secret exists: `sops sops/<hostname>.yaml`

### Check sops status

```bash
./scripts/check-sops.sh --verbose
```

## Legacy Instructions

For manual partitioning and traditional installation (not using nixos-anywhere), see the [NixOS manual](https://nixos.org/manual/nixos/stable/#sec-installation).

The key additional steps are:
1. Generate hardware config: `nixos-generate-config --root /mnt`
2. Copy to nix-config: `hosts/nixos/<hostname>/hardware-configuration.nix`
3. Follow the secrets setup above before first rebuild

---

[Return to top](#adding-a-new-host)

[README](../README.md) > Adding A New Host
