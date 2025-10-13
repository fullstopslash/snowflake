# Griefling Host Setup

## New Host: griefling

**Purpose**: Dev Lab VM with Hyprland desktop  
**User**: rain  
**Base**: Copied from grief host  
**Disk**: /dev/vda (VM virtual disk)

## Configuration

### Host Config
- **Location**: `hosts/nixos/griefling/default.nix`
- **Features**:
  - Hyprland desktop environment
  - Wayland support
  - User: rain
  - VM optimized (virtio drivers)

### Home-Manager Config
- **Location**: `home/rain/griefling.nix`
- **Includes**:
  - Hyprland configuration
  - Waybar, Rofi, GTK theming
  - Dunst notifications
  - Firefox browser
  - Helper scripts
  - Atuin shell history
  - SOPS secrets management

### Secrets Configuration
- **User age key**: rain_griefling generated
- **Host age key**: Will be generated during bootstrap
- **Secrets files**:
  - `sops/griefling.yaml` - Host-specific secrets (created)
  - `sops/shared.yaml` - Shared secrets (updated with griefling keys)

## Bootstrap Test Setup

### 1. Start the VM

```bash
cd /home/rain/nix-config
./griefling-test.sh
```

**VM Details:**
- RAM: 8GB
- CPUs: 2 cores, 2 threads
- Display: 1920x1080 with OpenGL
- SSH Port Forward: 22221 → 22
- Boots from: `result/iso/nixos-minimal-25.05.*.iso`

### 2. Wait for ISO to Boot

The VM window will appear. Wait for the NixOS ISO login prompt.

### 3. Run Bootstrap Script

From your host machine:

```bash
cd /home/rain/nix-config

./scripts/bootstrap-nixos.sh \
  -n griefling \
  -d 127.0.0.1 \
  -u rain \
  -k ~/.ssh/id_ed25519 \
  --port 22221 \
  --debug
```

### 4. Bootstrap Process

The script will prompt you through:
1. ✅ Run nixos-anywhere installation? (yes)
2. ✅ Generate hardware config? (yes - first time)
3. ✅ System restarted, ready to continue? (yes - after reboot)
4. ✅ Generate host age key? (yes)
5. ✅ Generate user age key? (no - already created manually)
6. ✅ Copy nix-config and nix-secrets? (yes)
7. ✅ Rebuild immediately? (yes)

### 5. What to Expect

**The Fixes in Action:**
- After reboot, script will wait up to 60 seconds for SSH
- You'll see: "Waiting for SSH service to be ready..."
- Progress: "Attempt N/30 - waiting 2 seconds..."
- Success: "SSH service is ready and accepting connections!"
- Age key generation will complete successfully

### 6. Post-Bootstrap

Once complete, you can SSH into griefling:

```bash
ssh -p 22221 -i ~/.ssh/id_ed25519 rain@127.0.0.1
```

And verify Hyprland is installed:

```bash
which Hyprland
systemctl status greetd  # Display manager
```

## Files Created/Modified

### nix-config
- ✅ `hosts/nixos/griefling/default.nix` - Host configuration
- ✅ `hosts/nixos/griefling/hardware-configuration.nix` - Copied from grief
- ✅ `home/rain/griefling.nix` - Home-manager configuration
- ✅ `nixos-installer/flake.nix` - Added griefling entry
- ✅ `griefling-test.sh` - VM launch script
- ✅ `griefling-test.qcow2` - VM disk (32GB)

### nix-secrets
- ✅ `.sops.yaml` - Added rain_griefling and griefling keys
- ✅ `sops/griefling.yaml` - Created with rain_griefling private key
- ✅ `sops/shared.yaml` - Rekeyed with griefling access

## Cleanup

To stop the VM and clean up after testing:

```bash
# Stop VM
pkill -f "qemu.*griefling-test"

# Optional: Remove test artifacts
rm griefling-test.qcow2
rm griefling-test.pid
rm griefling-test-*.socket
```

## Ready to Test!

The griefling host is fully configured and ready for bootstrap testing.

