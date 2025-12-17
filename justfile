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
  @(cd ../nix-secrets && source {{justfile_directory()}}/scripts/vcs-helpers.sh && vcs_pull > /dev/null) || true
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
# Remote Installation via mDNS (mitosis.local)
# ============================================================================
# Workflow:
#   1. Boot the ISO on target machine (builds with: just iso)
#   2. ISO auto-discovers network via DHCP and broadcasts as mitosis.local
#   3. Run: just install <hostname>
#   4. Done! Full NixOS installation in one command.
# ============================================================================

# Install NixOS on a machine booted from the mitosis ISO
# Usage: just install <hostname>
# The ISO must be booted and reachable at mitosis.local (via mDNS/Avahi)
install HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Installing {{HOST}} on mitosis.local..."

    # Verify the ISO is reachable
    echo "📡 Checking if mitosis.local is reachable..."
    if ! ping -c 1 -W 2 mitosis.local &>/dev/null; then
        echo "❌ Cannot reach mitosis.local"
        echo "   Make sure the ISO is booted and connected to the network."
        echo "   The ISO broadcasts via mDNS/Avahi as 'mitosis.local'"
        exit 1
    fi
    echo "✅ Found mitosis.local"

    # Create temp directory for extra-files
    EXTRA_FILES=$(mktemp -d)
    trap "rm -rf $EXTRA_FILES" EXIT

    # Step 1: Pre-generate SSH host key locally
    echo "🔑 Pre-generating SSH host key..."
    mkdir -p "$EXTRA_FILES/etc/ssh"
    ssh-keygen -t ed25519 -f "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key" -N "" -q
    chmod 600 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
    chmod 644 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"

    # Step 2: Derive age key from SSH host key
    echo "🔐 Deriving age key from SSH host key..."
    mkdir -p "$EXTRA_FILES/var/lib/sops-nix"
    nix-shell -p ssh-to-age --run "cat $EXTRA_FILES/etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key" > "$EXTRA_FILES/var/lib/sops-nix/key.txt"
    chmod 600 "$EXTRA_FILES/var/lib/sops-nix/key.txt"

    # Get age public key
    AGE_PUBKEY=$(nix-shell -p ssh-to-age --run "cat $EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age")
    echo "   Age public key: $AGE_PUBKEY"

    # Step 3: Register age key in nix-secrets and rekey
    echo "📝 Registering {{HOST}} age key in nix-secrets..."
    just sops-update-host-age-key {{HOST}} "$AGE_PUBKEY"
    just sops-add-creation-rules rain {{HOST}}

    # Rekey all secrets
    echo "   Rekeying secrets..."
    cd ../nix-secrets && for file in sops/*.yaml; do
        echo "     Rekeying $file..."
        sops updatekeys -y "$file"
    done

    # Commit and push
    echo "   Committing and pushing..."
    cd ../nix-secrets && \
        source {{justfile_directory()}}/scripts/vcs-helpers.sh && \
        vcs_add .sops.yaml sops/*.yaml && \
        (vcs_commit "chore: register {{HOST}} age key and rekey secrets" || true) && \
        vcs_push
    cd "{{justfile_directory()}}"

    # Step 4: Update local flake.lock to get rekeyed secrets
    echo "📥 Updating local nix-secrets flake input..."
    nix flake update nix-secrets

    # Step 5: Clear known_hosts for mitosis.local and the hostname
    echo "🧹 Clearing stale SSH host keys..."
    sed -i '/mitosis\.local/d; /{{HOST}}/d' ~/.ssh/known_hosts 2>/dev/null || true

    # Step 6: Get disk encryption password from SOPS
    echo "🔑 Retrieving disk encryption password from SOPS..."
    source {{HELPERS_PATH}}
    DISKO_PASSWORD=$(sops_get_disk_password {{HOST}})
    if [ -z "$DISKO_PASSWORD" ]; then
        echo "❌ Failed to retrieve disk password from SOPS"
        exit 1
    fi
    echo "   Password retrieved successfully"

    # Step 7: Run nixos-anywhere targeting mitosis.local
    echo "🚀 Running nixos-anywhere to install {{HOST}}..."

    # Create disko password file on installer if password is set
    if [[ -n ${DISKO_PASSWORD:-} ]]; then
        echo "   Creating disko password file on installer..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            root@mitosis.local \
            "echo '$DISKO_PASSWORD' > /tmp/disko-password && chmod 600 /tmp/disko-password"
    fi

    cd nixos-installer
    SHELL=/bin/sh nix run github:nix-community/nixos-anywhere -- \
        --extra-files "$EXTRA_FILES" \
        --flake .#{{HOST}} \
        root@mitosis.local
    cd - >/dev/null

    echo ""
    echo "✅ Installation complete!"
    echo "   {{HOST}} is now installed and will reboot."
    echo "   After reboot, SSH with: ssh root@{{HOST}}.local (if mDNS) or by IP"
    echo ""

# ============================================================================
# VM Testing Workflow
# ============================================================================
# Full workflow: just vm-fresh griefling
# This creates a fresh VM, installs NixOS, sets up secrets, and rebuilds
# ============================================================================

# Helper: Get primary username for a host from flake
_get-vm-primary-user HOST:
    @nix eval --raw .#nixosConfigurations.{{HOST}}.config.hostSpec.primaryUsername

# Complete fresh install: pre-generate keys, deploy FULL config directly via nixos-anywhere
# Uses --extra-files to include SSH host key + age key, eliminating the need for a second rebuild
vm-fresh HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Starting fresh VM install for {{HOST}}..."

    # Determine SSH port based on hostname
    declare -A VM_SSH_PORTS=(
        ["griefling"]="22222"
        ["sorrow"]="22223"
        ["torment"]="22224"
    )

    SSH_PORT="${VM_SSH_PORTS[{{HOST}}]:-22222}"

    # Create temp directory for extra-files
    EXTRA_FILES=$(mktemp -d)
    trap "rm -rf $EXTRA_FILES" EXIT

    # Step 1: Pre-generate SSH host key locally
    echo "🔑 Pre-generating SSH host key..."
    mkdir -p "$EXTRA_FILES/etc/ssh"
    ssh-keygen -t ed25519 -f "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key" -N "" -q
    chmod 600 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
    chmod 644 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"

    # Step 2: Derive age key from SSH host key
    echo "🔐 Deriving age key from SSH host key..."
    mkdir -p "$EXTRA_FILES/var/lib/sops-nix"
    nix-shell -p ssh-to-age --run "cat $EXTRA_FILES/etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key" > "$EXTRA_FILES/var/lib/sops-nix/key.txt"
    chmod 600 "$EXTRA_FILES/var/lib/sops-nix/key.txt"

    # Get age public key
    AGE_PUBKEY=$(nix-shell -p ssh-to-age --run "cat $EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age")
    echo "   Age public key: $AGE_PUBKEY"

    # Step 3: Register age key in nix-secrets and rekey
    echo "📝 Registering {{HOST}} age key in nix-secrets..."
    just sops-update-host-age-key {{HOST}} "$AGE_PUBKEY"
    just sops-add-creation-rules rain {{HOST}}

    # Rekey all secrets
    echo "   Rekeying secrets..."
    cd ../nix-secrets && for file in sops/*.yaml; do
        echo "     Rekeying $file..."
        sops updatekeys -y "$file"
    done

    # Commit and push
    echo "   Committing and pushing..."
    cd ../nix-secrets && \
        source {{justfile_directory()}}/scripts/vcs-helpers.sh && \
        vcs_add .sops.yaml sops/*.yaml && \
        (vcs_commit "chore: register {{HOST}} age key and rekey secrets" || true) && \
        vcs_push
    cd "{{justfile_directory()}}"

    # Step 4: Update local flake.lock to get rekeyed secrets
    echo "📥 Updating local nix-secrets flake input..."
    nix flake update nix-secrets

    # Step 4.5: Get disk encryption password from SOPS
    echo "🔑 Retrieving disk encryption password from SOPS..."
    source {{HELPERS_PATH}}
    DISKO_PASSWORD=$(sops_get_disk_password {{HOST}})
    if [ -z "$DISKO_PASSWORD" ]; then
        echo "❌ Failed to retrieve disk password from SOPS"
        exit 1
    fi
    echo "   Password retrieved successfully"

    # Step 5: Start VM and run nixos-anywhere with FULL config
    echo "🚀 Starting VM and deploying FULL configuration..."
    DISKO_PASSWORD="$DISKO_PASSWORD" ./scripts/test-fresh-install.sh {{HOST}} --anywhere --force --ssh-port "$SSH_PORT" --extra-files "$EXTRA_FILES"

    echo ""
    echo "✅ Fresh install complete!"
    echo "   SSH: ssh -p $SSH_PORT root@127.0.0.1"
    echo "   Display: just vm-start (SDL with GPU acceleration)"
    echo ""
    echo "   The system is fully configured - no second rebuild needed!"

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

# Register VM's age key in nix-secrets repo and rekey secrets
vm-register-age HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📝 Registering {{HOST}} age key in nix-secrets..."

    # Get the VM's age private key and derive public key locally
    PRIVKEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1 \
        "cat /var/lib/sops-nix/key.txt" 2>/dev/null)

    if [ -z "$PRIVKEY" ]; then
        echo "❌ Age key not found on VM. Run 'just vm-setup-age {{HOST}}' first."
        exit 1
    fi

    # Derive public key from private key locally
    PUBKEY=$(echo "$PRIVKEY" | nix-shell -p age --run "age-keygen -y")

    echo "   Age public key: $PUBKEY"

    # Update .sops.yaml with the host age key
    echo "   Updating .sops.yaml..."
    just sops-update-host-age-key {{HOST}} "$PUBKEY"

    # Add creation rules if they don't exist (user is 'rain' for test VMs)
    echo "   Ensuring creation rules exist..."
    just sops-add-creation-rules rain {{HOST}}

    # Rekey all secrets to include the new host
    echo "   Rekeying secrets..."
    cd ../nix-secrets && for file in sops/*.yaml; do \
        echo "     Rekeying $file..."; \
        sops updatekeys -y "$file"; \
    done

    # Commit and push changes
    echo "   Committing changes..."
    cd ../nix-secrets && \
        source {{justfile_directory()}}/scripts/vcs-helpers.sh && \
        vcs_add .sops.yaml sops/*.yaml && \
        (vcs_commit "chore: register {{HOST}} age key and rekey secrets" || true) && \
        vcs_push

    echo "✅ Age key registered and secrets rekeyed"
    echo "   Host {{HOST}} can now decrypt secrets on next rebuild"
    echo "   Secrets pushed to GitHub - VM will pull on next rebuild"

# Sync nix-config to running VM via git push over SSH
vm-sync HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Syncing nix-config to VM via git..."

    USER=$(just _get-vm-primary-user {{HOST}})
    USER_HOME="/home/$USER"
    VM_REMOTE="vm-{{HOST}}"
    VM_URL="ssh://$USER@127.0.0.1:{{VM_SSH_PORT}}$USER_HOME/nix-config"

    # Add VM as git remote if not exists, update URL if changed
    if git remote get-url "$VM_REMOTE" &>/dev/null; then
        git remote set-url "$VM_REMOTE" "$VM_URL"
    else
        git remote add "$VM_REMOTE" "$VM_URL"
    fi

    # Configure VM repo to receive pushes to checked-out branch
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} $USER@127.0.0.1 \
        "git -C $USER_HOME/nix-config config receive.denyCurrentBranch updateInstead"

    # Push current HEAD to the VM
    git push --force "$VM_REMOTE" HEAD:dev

    echo "✅ Config synced to $USER_HOME/nix-config"

# Rebuild NixOS on running VM (uses user's home directory)
vm-rebuild HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Rebuilding NixOS on VM..."

    USER=$(just _get-vm-primary-user {{HOST}})
    USER_HOME="/home/$USER"
    # Use nh for better output; run as user (nh calls sudo internally)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} $USER@127.0.0.1 \
        "nh os switch $USER_HOME/nix-config"

    echo "✅ Rebuild complete"

# SSH into the VM
vm-ssh HOST=DEFAULT_VM_HOST:
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{VM_SSH_PORT}} root@127.0.0.1

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
        echo "   Display: just vm-start (use SDL window)"
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

# ========================================
# Multi-VM Management (sorrow, torment, griefling)
# ========================================
# For testing GitOps workflows with concurrent VMs
# Each VM has unique SSH/SPICE ports to run simultaneously

# Start a test VM (supports concurrent VMs with unique ports)
test-vm-start VM:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu coreutils
    ./scripts/multi-vm.sh start {{VM}}

# Stop a test VM
test-vm-stop VM:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu coreutils
    ./scripts/multi-vm.sh stop {{VM}}

# SSH into a test VM
test-vm-ssh VM:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu coreutils openssh
    ./scripts/multi-vm.sh ssh {{VM}}

# Show status of all test VMs
test-vm-status:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu coreutils
    ./scripts/multi-vm.sh status

# Start all test VMs (griefling, sorrow, torment)
test-vm-start-all:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu coreutils
    ./scripts/multi-vm.sh start-all

# Stop all test VMs
test-vm-stop-all:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu coreutils
    ./scripts/multi-vm.sh stop-all

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
  #!/usr/bin/env bash
  set -e
  cd ../nix-secrets
  pre-commit run --all-files || true
  source ../nix-config/scripts/vcs-helpers.sh
  vcs_add -u
  vcs_commit "chore: rekey" || true
  vcs_push

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

# Initialize key metadata for existing host
sops-init-key-metadata HOST:
  @echo "Initializing key metadata for {{HOST}}..."
  bash -c "source scripts/helpers.sh && sops_init_key_metadata {{HOST}}"

# Rotate SOPS key for host (interactive, zero-downtime)
sops-rotate HOST:
  @echo "Starting key rotation for {{HOST}}..."
  bash scripts/sops-rotate.sh sops_rotate_host {{HOST}}

# Check age of all host keys
sops-check-key-age:
  #!/usr/bin/env bash
  set -e
  echo "Host Key Age Report"
  echo "==================="
  cd ../nix-secrets/sops
  for yaml in *.yaml; do
    hostname="${yaml%.yaml}"
    if [ "$hostname" != "shared" ]; then
      if sops -d "$yaml" | grep -q "key-metadata"; then
        generated=$(sops -d "$yaml" | yq '.sops.key-metadata.generated_at')
        rotated=$(sops -d "$yaml" | yq '.sops.key-metadata.rotated_at')
        echo "$hostname: generated=$generated, last_rotated=$rotated"
      else
        echo "$hostname: no metadata"
      fi
    fi
  done

# ============================================================================
# Disk Encryption
# ============================================================================

# Setup TPM2 automatic unlock for bcachefs encryption
bcachefs-setup-tpm HOST:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔐 Setting up TPM2 automatic unlock for bcachefs on {{HOST}}"

    # Check if TPM is enabled in host config
    if ! nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.enable 2>/dev/null | grep -q "true"; then
        echo "❌ TPM unlock not enabled for {{HOST}}"
        echo "   Add 'host.encryption.tpm.enable = true;' to your host configuration"
        exit 1
    fi

    # Get persist folder and PCR IDs from config
    PERSIST_FOLDER=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.persistFolder 2>/dev/null || echo "")
    PCR_IDS=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.pcrIds 2>/dev/null || echo "7")

    if [ -z "$PERSIST_FOLDER" ]; then
        echo "❌ persistFolder not set for {{HOST}}"
        echo "   Set host.persistFolder in your host configuration"
        exit 1
    fi

    TOKEN_FILE="${PERSIST_FOLDER}/etc/clevis/bcachefs-root.jwe"

    # Create directory for token
    echo "📁 Creating Clevis token directory..."
    mkdir -p "$(dirname "$TOKEN_FILE")"

    # Get disk password from SOPS
    echo "🔑 Retrieving disk encryption password from SOPS..."
    source {{HELPERS_PATH}}
    DISK_PASSWORD=$(sops_get_disk_password {{HOST}})
    if [ -z "$DISK_PASSWORD" ]; then
        echo "❌ Failed to retrieve disk password from SOPS"
        exit 1
    fi
    echo "   Password retrieved successfully"

    # Generate Clevis JWE token with TPM2
    echo "🔐 Generating TPM2 Clevis token (PCR $PCR_IDS)..."
    echo "$DISK_PASSWORD" | clevis encrypt tpm2 '{"pcr_ids":"'"$PCR_IDS"'"}' > "$TOKEN_FILE"

    # Set proper permissions
    chmod 600 "$TOKEN_FILE"
    chown root:root "$TOKEN_FILE"

    echo "✅ TPM token generated successfully!"
    echo "   Token location: $TOKEN_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Rebuild system: sudo nixos-rebuild switch"
    echo "  2. Reboot to test automatic unlock"
    echo ""
    echo "The token is bound to TPM PCR $PCR_IDS (Secure Boot state)"
