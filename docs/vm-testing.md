# VM Testing Workflow

## Quick Start

### Start a VM for testing
```bash
# Headless (SSH only, runs in background)
./scripts/start-vm-headless.sh <hostname> [ssh-port] [memory-gb]

# GUI (requires local display)
./scripts/start-vm-gui.sh <hostname> [ssh-port] [memory-gb]

# Examples:
./scripts/start-vm-headless.sh griefling 22221 16
./scripts/start-vm-headless.sh guppy 22222 8
```

### Stop a VM
```bash
./scripts/stop-vm.sh <hostname>
```

### Clean up all VM files
```bash
rm -rf quickemu/
```

## How It Works

When you start a VM with a fresh hostname:
1. Creates `quickemu/<hostname>-test.qcow2` (100GB disk)
2. Creates `quickemu/<hostname>-OVMF_VARS.fd` (UEFI vars)
3. Builds the minimal installer ISO for that host if needed
4. Boots from ISO for initial installation
5. After installation, subsequent starts boot from disk

## Testing the Bootstrap Process

```bash
# 1. Start a fresh VM
./scripts/start-vm-headless.sh myhost 22223 16

# 2. Wait for boot, then run bootstrap
./scripts/bootstrap-nixos.sh myhost 127.0.0.1:22223

# 3. SSH to verify
ssh -p 22223 -i ~/.ssh/id_ed25519 rain@127.0.0.1

# 4. Clean up when done
./scripts/stop-vm.sh myhost
rm -rf quickemu/myhost-*
```

## File Organization

All VM artifacts go to `quickemu/` (git-ignored):
- `<hostname>-test.qcow2` - Virtual disk
- `<hostname>-OVMF_VARS.fd` - UEFI variables
- `<hostname>-test.pid` - Process ID
- `<hostname>-test-*.socket` - QEMU sockets
