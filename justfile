SOPS_FILE := "../nix-secrets/.sops.yaml"

# Define path to helpers
export HELPERS_PATH := justfile_directory() + "/scripts/helpers.sh"

# Default host for VM testing
DEFAULT_VM_HOST := "griefling"

# VM Configuration
VM_SSH_PORT := "22222"
VM_SPICE_PORT := "5930"
VM_MEMORY := "8"
VM_DISK_SIZE := "50"

# default recipe to display help information
default:
  @just --list

# Update commonly changing flakes and prep for a rebuild
rebuild-pre: update-nix-secrets
  @git add --intent-to-add .

# Run post-rebuild checks, like if sops is running properly afterwards
rebuild-post: check-sops

# Run a flake check on the config and installer
check ARGS="":
	NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace {{ARGS}}
	cd nixos-installer && NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace {{ARGS}}

# Rebuild the system
rebuild: rebuild-pre && rebuild-post
  # NOTE: Add --option eval-cache false if you end up caching a failure you can't get around
  scripts/rebuild.sh

# Rebuild the system and run a flake check
rebuild-full: rebuild-pre && rebuild-post
  scripts/rebuild.sh
  just check

# Rebuild the system and run a flake check
rebuild-trace: rebuild-pre && rebuild-post
  scripts/rebuild.sh trace
  just check

# Update the flake
update:
  nix flake update

# Update and then rebuild
rebuild-update: update rebuild

# Git diff there entire repo expcept for flake.lock
diff:
  git diff ':!flake.lock'

# Generate a new age key
age-key:
  nix-shell -p age --run "age-keygen"

# Check if sops-nix activated successfully
check-sops:
  scripts/check-sops.sh

# Update nix-secrets flake
update-nix-secrets:
  @(cd ../nix-secrets && git fetch && git rebase > /dev/null) || true
  nix flake update nix-secrets --timeout 5

# Build an iso image for installing new systems and create a symlink for qemu usage
iso:
  # If we dont remove this folder, libvirtd VM doesnt run with the new iso...
  rm -rf result
  nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage && ln -sf result/iso/*.iso latest.iso

# Install the latest iso to a flash drive
iso-install DRIVE: iso
  sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

# ============================================================================
# VM Testing Workflow
# ============================================================================
# Full workflow: just vm-fresh griefling
# This creates a fresh VM, installs NixOS, sets up secrets, and rebuilds
# ============================================================================

# Complete fresh install: wipe, install, setup age key, sync config, rebuild
vm-fresh HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Starting fresh VM install for {{HOST}}..."

    # Step 1: Fresh install with nixos-anywhere (wipes and installs base system)
    ./scripts/test-fresh-install.sh {{HOST}} --anywhere --force

    # Step 2: Wait for VM to reboot after nixos-anywhere
    echo ""
    echo "⏳ Waiting 45s for VM to reboot..."
    sleep 45

    # Step 3: Wait for SSH
    echo "🔌 Waiting for SSH..."
    for i in {1..30}; do
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -p {{VM_SSH_PORT}} root@127.0.0.1 true 2>/dev/null; then
            echo "✅ SSH ready"
            break
        fi
        sleep 2
        printf "."
    done
    echo ""

    # Step 4: Setup age key from SSH host key
    just vm-setup-age {{HOST}}

    # Step 5: Sync and rebuild
    just vm-sync {{HOST}}
    just vm-rebuild {{HOST}}

    echo ""
    echo "✅ Fresh install complete!"
    echo "   SSH: ssh -p {{VM_SSH_PORT}} root@127.0.0.1"
    echo "   SPICE: just vm-spice"

# Setup age key on VM from SSH host key (required for SOPS secrets)
vm-setup-age HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔐 Setting up age key from SSH host key..."

    # Get SSH host key and derive age key
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1 \
        "mkdir -p /var/lib/sops-nix && \
         cat /etc/ssh/ssh_host_ed25519_key | nix-shell -p ssh-to-age --run 'ssh-to-age -private-key' > /var/lib/sops-nix/key.txt && \
         chmod 600 /var/lib/sops-nix/key.txt"

    # Show the public key for .sops.yaml
    PUBKEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1 \
        "cat /etc/ssh/ssh_host_ed25519_key.pub | nix-shell -p ssh-to-age --run 'ssh-to-age'")
    echo "✅ Age key installed"
    echo "   Public key: $PUBKEY"

# Sync nix-config to running VM
vm-sync HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Syncing nix-config to VM..."

    # Add git safe.directory on VM
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1 \
        "git config --global --add safe.directory /root/nix-config" 2>/dev/null || true

    # Rsync excluding large files and .git
    rsync -avz --delete \
        --exclude='*.qcow2' \
        --exclude='.git' \
        --exclude='result' \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}}" \
        . root@127.0.0.1:/root/nix-config/

    echo "✅ Config synced to /root/nix-config"

# Rebuild NixOS on running VM
vm-rebuild HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Rebuilding NixOS on VM..."

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1 \
        "cd /root/nix-config && nixos-rebuild switch --flake .#{{HOST}}"

    echo "✅ Rebuild complete"

# SSH into the VM
vm-ssh HOST=DEFAULT_VM_HOST:
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1

# Open SPICE viewer to see VM display
vm-spice:
    nix-shell -p spice-gtk --run "spicy -h 127.0.0.1 -p {{VM_SPICE_PORT}}"

# Stop the running VM
vm-stop HOST=DEFAULT_VM_HOST:
    ./scripts/stop-vm.sh {{HOST}}

# Check VM status
vm-status HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    PID_FILE="quickemu/{{HOST}}-test.pid"
    if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "✅ VM {{HOST}} is running (PID: $(cat "$PID_FILE"))"
        echo "   SSH: ssh -p {{VM_SSH_PORT}} root@127.0.0.1"
        echo "   SPICE: just vm-spice"
    else
        echo "❌ VM {{HOST}} is not running"
    fi

# Start existing VM with GUI (virtio-vga-gl + SDL for hardware acceleration)
vm-start HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu
    set -euo pipefail

    QCOW2="quickemu/{{HOST}}-test.qcow2"
    if [ ! -f "$QCOW2" ]; then
        echo "❌ No disk image found. Run 'just vm-fresh {{HOST}}' first."
        exit 1
    fi

    PID_FILE="quickemu/{{HOST}}-test.pid"
    if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "VM {{HOST}} is already running (PID: $(cat "$PID_FILE"))"
        exit 0
    fi

    echo "🚀 Starting VM {{HOST}} with GPU acceleration..."

    # Get OVMF paths
    OVMF_PATH=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link 2>/dev/null)
    OVMF_CODE="$OVMF_PATH/FV/OVMF_CODE.fd"
    OVMF_VARS="quickemu/{{HOST}}-OVMF_VARS.fd"

    # Use virtio-vga-gl with SDL for best Wayland/Hyprland performance
    qemu-system-x86_64 \
        -name "{{HOST}}-test" \
        -machine q35,smm=off,vmport=off,accel=kvm \
        -cpu host,topoext \
        -smp cores=2,threads=2,sockets=1 \
        -m {{VM_MEMORY}}G \
        -pidfile "$PID_FILE" \
        -vga none \
        -device virtio-vga-gl,xres=1920,yres=1080 \
        -display sdl,gl=on \
        -device virtio-rng-pci,rng=rng0 \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device qemu-xhci,id=input \
        -device usb-kbd,bus=input.0 \
        -device usb-tablet,bus=input.0 \
        -audiodev pipewire,id=audio0 \
        -device intel-hda \
        -device hda-micro,audiodev=audio0 \
        -device virtio-net,netdev=nic \
        -netdev "user,hostname={{HOST}},hostfwd=tcp::{{VM_SSH_PORT}}-:22,id=nic" \
        -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
        -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
        -device virtio-blk-pci,drive=SystemDisk \
        -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" &

    sleep 2
    echo "✅ VM started with SDL display (hardware accelerated)"
    echo "   SSH: ssh -p {{VM_SSH_PORT}} root@127.0.0.1"

# Start VM headless (no display, SSH only)
vm-start-headless HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu
    set -euo pipefail

    QCOW2="quickemu/{{HOST}}-test.qcow2"
    if [ ! -f "$QCOW2" ]; then
        echo "❌ No disk image found. Run 'just vm-fresh {{HOST}}' first."
        exit 1
    fi

    PID_FILE="quickemu/{{HOST}}-test.pid"
    if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "VM {{HOST}} is already running (PID: $(cat "$PID_FILE"))"
        exit 0
    fi

    echo "🚀 Starting VM {{HOST}} headless..."

    OVMF_PATH=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link 2>/dev/null)
    OVMF_CODE="$OVMF_PATH/FV/OVMF_CODE.fd"
    OVMF_VARS="quickemu/{{HOST}}-OVMF_VARS.fd"

    qemu-system-x86_64 \
        -name "{{HOST}}-test" \
        -machine q35,smm=off,vmport=off,accel=kvm \
        -cpu host,topoext \
        -smp cores=2,threads=2,sockets=1 \
        -m {{VM_MEMORY}}G \
        -pidfile "$PID_FILE" \
        -display none \
        -device virtio-rng-pci,rng=rng0 \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device virtio-net,netdev=nic \
        -netdev "user,hostname={{HOST}},hostfwd=tcp::{{VM_SSH_PORT}}-:22,id=nic" \
        -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
        -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
        -device virtio-blk-pci,drive=SystemDisk \
        -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" \
        -daemonize

    echo "✅ VM started (headless)"
    echo "   SSH: ssh -p {{VM_SSH_PORT}} root@127.0.0.1"

# Quick rebuild: sync and rebuild on running VM (no fresh install)
vm-quick HOST=DEFAULT_VM_HOST: (vm-sync HOST) (vm-rebuild HOST)

# Bootstrap a new NixOS host (disko + install via nixos-anywhere)
# See nixos-installer/README.md for full documentation
# Usage: just bootstrap <host> <ip> <ssh-key> [port]
# Example: just bootstrap griefling 127.0.0.1 ~/.ssh/id_ed25519 22222
bootstrap HOST DEST KEY PORT="22":
  ./scripts/bootstrap-nixos.sh -n {{HOST}} -d {{DEST}} -k {{KEY}} --port {{PORT}}

# Copy all the config files to the remote host
sync USER HOST PATH:
	rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}} -oport=22" . {{USER}}@{{HOST}}:{{PATH}}/nix-config

# Run nixos-rebuild on the remote host
build-host HOST:
	NIX_SSHOPTS="-p22" nixos-rebuild --target-host {{HOST}} --use-remote-sudo --show-trace --impure --flake .#"{{HOST}}" switch

# Called by the rekey recipe
sops-rekey:
  cd ../nix-secrets && for file in $(ls sops/*.yaml); do \
    sops updatekeys -y $file; \
  done

# Update all keys in sops/*.yaml files in nix-secrets to match the creation rules keys
rekey: sops-rekey
  cd ../nix-secrets && \
    (pre-commit run --all-files || true) && \
    git add -u && (git commit -nm "chore: rekey" || true) && git push

# Update an age key anchor or add a new one
sops-update-age-key FIELD KEYNAME KEY:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_update_age_key {{FIELD}} {{KEYNAME}} {{KEY}}

# Update an existing user age key anchor or add a new one
sops-update-user-age-key USER HOST KEY:
  just sops-update-age-key users {{USER}}_{{HOST}} {{KEY}}

# Update an existing host age key anchor or add a new one
sops-update-host-age-key HOST KEY:
  just sops-update-age-key hosts {{HOST}} {{KEY}}

# Automatically create creation rules entries for a <host>.yaml file for host-specific secrets
sops-add-host-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_add_host_creation_rules "{{USER}}" "{{HOST}}"

# Automatically create creation rules entries for a shared.yaml file for shared secrets
sops-add-shared-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_add_shared_creation_rules "{{USER}}" "{{HOST}}"

# Automatically add the host and user keys to creation rules for shared.yaml and <host>.yaml
sops-add-creation-rules USER HOST:
    just sops-add-host-creation-rules {{USER}} {{HOST}} && \
    just sops-add-shared-creation-rules {{USER}} {{HOST}}
