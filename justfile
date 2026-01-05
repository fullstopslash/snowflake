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

# Rebuild the system with full sync workflow (upstream + dotfiles + rebuild)
# Triggers systemd service with flag support: --skip-upstream, --skip-dotfiles, --skip-update, --update, --dry-run, --offline
rebuild *FLAGS:
  #!/usr/bin/env bash
  set -euo pipefail

  # Parse flags and convert to environment variables
  export SKIP_UPSTREAM=false
  export SKIP_DOTFILES=false
  export SKIP_UPDATE=true
  export DRY_RUN=false
  export OFFLINE=false

  for flag in {{FLAGS}}; do
    case "$flag" in
      --skip-upstream)
        export SKIP_UPSTREAM=true
        ;;
      --skip-dotfiles)
        export SKIP_DOTFILES=true
        ;;
      --skip-update)
        export SKIP_UPDATE=true
        ;;
      --update)
        export SKIP_UPDATE=false
        ;;
      --dry-run)
        export DRY_RUN=true
        ;;
      --offline)
        export OFFLINE=true
        export SKIP_UPSTREAM=true
        export SKIP_DOTFILES=true
        ;;
      *)
        echo "Unknown flag: $flag"
        echo "Supported flags: --skip-upstream, --skip-dotfiles, --skip-update, --update, --dry-run, --offline"
        exit 1
        ;;
    esac
  done

  # Show active flags
  echo "Rebuild flags:"
  echo "  SKIP_UPSTREAM=$SKIP_UPSTREAM"
  echo "  SKIP_DOTFILES=$SKIP_DOTFILES"
  echo "  SKIP_UPDATE=$SKIP_UPDATE"
  echo "  DRY_RUN=$DRY_RUN"
  echo "  OFFLINE=$OFFLINE"
  echo ""

  # Set environment for systemd manager (so service can inherit)
  sudo systemctl set-environment \
    SKIP_UPSTREAM=$SKIP_UPSTREAM \
    SKIP_DOTFILES=$SKIP_DOTFILES \
    SKIP_UPDATE=$SKIP_UPDATE \
    DRY_RUN=$DRY_RUN \
    OFFLINE=$OFFLINE

  # Trigger systemd service
  echo "Starting nix-local-upgrade.service..."
  sudo systemctl start nix-local-upgrade.service

  # Follow logs in real-time
  echo ""
  echo "Following logs (Ctrl+C to exit):"
  journalctl -fu nix-local-upgrade.service --since "1 minute ago"

  # Clean up environment variables
  sudo systemctl unset-environment SKIP_UPSTREAM SKIP_DOTFILES SKIP_UPDATE DRY_RUN OFFLINE

# Rebuild with flake update
rebuild-update:
  @just rebuild --update

# Offline rebuild (skip upstream/dotfiles sync)
rebuild-offline:
  @just rebuild --offline

# Dry run to see what would be done
rebuild-dry:
  @just rebuild --dry-run

# Local-only rebuild (fast, no sync, for quick iterations)
rebuild-local: rebuild-pre && rebuild-post
  # NOTE: Add --option eval-cache false if you end up caching a failure you can't get around
  scripts/rebuild.sh

# Local rebuild with flake update
rebuild-local-update: update rebuild-local

# Local rebuild with full flake check
rebuild-local-full: rebuild-pre && rebuild-post
  scripts/rebuild.sh
  just check

# Local rebuild with trace output
rebuild-local-trace: rebuild-pre && rebuild-post
  scripts/rebuild.sh trace
  just check

# Update the flake
update:
  nix flake update

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
# Install Automation Helpers (DRY - used by both install and vm-fresh)
# ============================================================================

# Helper: Deploy SSH host keys to both root and user on target system
_deploy-host-keys HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔑 Deploying SSH host keys to {{HOST}}..."
    # Keys are already deployed via nixos-anywhere --extra-files
    # This is a placeholder for any post-deployment key setup if needed
    echo "   ✅ SSH host keys deployed"

# Helper: Configure SSH config for GitHub on target system
_configure-ssh-github HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Configuring SSH for GitHub on {{HOST}}..."

    # Configure root SSH with per-repo aliases
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{SSH_TARGET}} \
        'chmod 600 ~/.ssh/*-deploy && \
         printf "Host github.com-nix-config\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/nix-config-deploy\n    StrictHostKeyChecking no\n\nHost github.com-nix-secrets\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/nix-secrets-deploy\n    StrictHostKeyChecking no\n\nHost github.com-chezmoi\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/chezmoi-deploy\n    StrictHostKeyChecking no\n" > ~/.ssh/config && \
         chmod 600 ~/.ssh/config'

    # Configure user SSH with per-repo aliases
    echo "🔑 Setting up SSH config for user {{PRIMARY_USER}}..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{SSH_TARGET}} \
        'if [ -d /persist/home/{{PRIMARY_USER}} ] || ([ -d /persist ] && findmnt /home > /dev/null 2>&1); then \
             USER_HOME=/persist/home/{{PRIMARY_USER}}; \
         else \
             USER_HOME=/home/{{PRIMARY_USER}}; \
         fi && \
         mkdir -p $USER_HOME/.ssh && \
         cp /root/.ssh/nix-config-deploy $USER_HOME/.ssh/ && \
         cp /root/.ssh/nix-secrets-deploy $USER_HOME/.ssh/ && \
         cp /root/.ssh/chezmoi-deploy $USER_HOME/.ssh/ && \
         printf "Host github.com-nix-config\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/nix-config-deploy\n    StrictHostKeyChecking no\n\nHost github.com-nix-secrets\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/nix-secrets-deploy\n    StrictHostKeyChecking no\n\nHost github.com-chezmoi\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/chezmoi-deploy\n    StrictHostKeyChecking no\n" > $USER_HOME/.ssh/config && \
         chmod 600 $USER_HOME/.ssh/nix-config-deploy $USER_HOME/.ssh/nix-secrets-deploy $USER_HOME/.ssh/chezmoi-deploy $USER_HOME/.ssh/config && \
         chown -R {{PRIMARY_USER}}:users $USER_HOME/.ssh && \
         echo "✅ SSH config configured for {{PRIMARY_USER}}"'

# Helper: Clone repos (nix-config, nix-secrets, chezmoi) to correct location with /persist detection
_clone-repos HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📥 Ensuring all repos present on {{HOST}}..."

    # Use robust /persist detection
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{SSH_TARGET}} \
        "set -e && \
         if [ -d /persist/home/{{PRIMARY_USER}} ] || ([ -d /persist ] && findmnt /home > /dev/null 2>&1); then \
             USER_HOME=/persist/home/{{PRIMARY_USER}} && \
             mkdir -p /persist/home && \
             echo '→ Encrypted host detected, using /persist/home/{{PRIMARY_USER}}'; \
         else \
             USER_HOME=/home/{{PRIMARY_USER}} && \
             echo '→ Regular host, using /home/{{PRIMARY_USER}}'; \
         fi && \
         mkdir -p \$USER_HOME && \
         cd \$USER_HOME && \
         \
         # Check if repos already exist (deployed via EXTRA_FILES) \
         if [ -d nix-config/.git ] && [ -d nix-secrets/.git ] && [ -d .local/share/chezmoi/.git ]; then \
             echo '✅ All repos already present (deployed via EXTRA_FILES)'; \
             echo '   Verified: nix-config/.git exists'; \
             echo '   Verified: nix-secrets/.git exists'; \
             echo '   Verified: .local/share/chezmoi/.git exists'; \
         else \
             echo '→ Repos not found, cloning from GitHub...'; \
             rm -rf nix-config nix-secrets .local/share/chezmoi && \
             echo '→ Cloning nix-config...' && \
             git clone git@github.com-nix-config:fullstopslash/snowflake.git nix-config && \
             [ -d nix-config/.git ] || (echo '❌ Failed to clone nix-config' && exit 1) && \
             echo '→ Cloning nix-secrets...' && \
             git clone git@github.com-nix-secrets:fullstopslash/snowflake-secrets.git nix-secrets && \
             [ -d nix-secrets/.git ] || (echo '❌ Failed to clone nix-secrets' && exit 1) && \
             echo '→ Cloning dotfiles...' && \
             mkdir -p .local/share && \
             git clone git@github.com-chezmoi:fullstopslash/dotfiles.git .local/share/chezmoi && \
             [ -d .local/share/chezmoi/.git ] || (echo '❌ Failed to clone chezmoi' && exit 1) && \
             echo '✅ All repos cloned successfully to '\$USER_HOME; \
         fi && \
         USER_ID=\$(id -u {{PRIMARY_USER}} 2>/dev/null || echo 1000) && \
         GROUP_ID=\$(id -g {{PRIMARY_USER}} 2>/dev/null || echo 100) && \
         chown -R \$USER_ID:\$GROUP_ID \$USER_HOME"

# Helper: Setup SOPS keys (auto-extract, update .sops.yaml, rekey)
_setup-sops-keys HOST AGE_PUBKEY USER_AGE_PUBKEY PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📝 Registering {{HOST}} age key in nix-secrets..."

    # Update .sops.yaml with the host age key
    just sops-update-host-age-key {{HOST}} "{{AGE_PUBKEY}}"

    # Add per-host user age key for granular access control
    just sops-update-user-age-key {{PRIMARY_USER}} {{HOST}} "{{USER_AGE_PUBKEY}}"

    # Add creation rules
    just sops-add-creation-rules {{PRIMARY_USER}} {{HOST}}

    # Rekey all secrets
    echo "   Rekeying secrets..."
    cd ../nix-secrets && for file in sops/*.yaml; do
        echo "     Rekeying $file..."
        sops updatekeys -y "$file"
    done

    # Commit and push (includes age keys + rekeyed secrets)
    echo "   Committing and pushing..."
    cd ../nix-secrets && \
        source {{justfile_directory()}}/scripts/vcs-helpers.sh && \
        vcs_add .sops.yaml sops/*.yaml && \
        (vcs_commit "chore: register {{HOST}} age key and rekey secrets" || true) && \
        vcs_push
    cd "{{justfile_directory()}}"

    echo "   ✅ SOPS keys registered and secrets rekeyed"

# Helper: Generate deploy keys and store in SOPS (for NixOS module deployment)
_generate-deploy-keys HOST:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔑 Generating deploy keys for {{HOST}}..."

    cd ../nix-secrets

    # Check if ALL THREE deploy keys exist
    if sops -d --extract '["deploy-keys"]["nix-config"]' sops/{{HOST}}.yaml >/dev/null 2>&1 && \
       sops -d --extract '["deploy-keys"]["nix-secrets"]' sops/{{HOST}}.yaml >/dev/null 2>&1 && \
       sops -d --extract '["deploy-keys"]["chezmoi"]' sops/{{HOST}}.yaml >/dev/null 2>&1; then
        echo "   ✅ Deploy keys already exist in SOPS"
        cd {{justfile_directory()}}
        exit 0
    fi

    echo "   Generating new deploy keys..."
    TEMP_DIR=$(mktemp -d)
    ssh-keygen -t ed25519 -f "$TEMP_DIR/nix-config-deploy" -N "" -C "{{HOST}}-nix-config-deploy" -q
    ssh-keygen -t ed25519 -f "$TEMP_DIR/nix-secrets-deploy" -N "" -C "{{HOST}}-nix-secrets-deploy" -q
    ssh-keygen -t ed25519 -f "$TEMP_DIR/chezmoi-deploy" -N "" -C "{{HOST}}-chezmoi-deploy" -q

    echo "   Adding deploy keys to GitHub..."
    gh repo deploy-key add "$TEMP_DIR/nix-config-deploy.pub" -R fullstopslash/snowflake -t "{{HOST}}-nix-config-deploy" 2>/dev/null || echo "   (Key may already exist)"
    gh repo deploy-key add "$TEMP_DIR/nix-secrets-deploy.pub" -R fullstopslash/snowflake-secrets -t "{{HOST}}-nix-secrets-deploy" 2>/dev/null || echo "   (Key may already exist)"
    gh repo deploy-key add "$TEMP_DIR/chezmoi-deploy.pub" -R fullstopslash/dotfiles -t "{{HOST}}-chezmoi-deploy" 2>/dev/null || echo "   (Key may already exist)"

    # Store deploy keys in SOPS
    TMP_YAML=$(mktemp)
    # Try to decrypt existing file, create minimal structure if it fails
    if sops -d sops/{{HOST}}.yaml 2>/dev/null | yq 'del(.sops)' > $TMP_YAML 2>/dev/null; then
        echo "   Using existing SOPS file structure"
    else
        echo "   Creating fresh SOPS file structure"
        echo "{}" > $TMP_YAML
    fi

    # Add deploy-keys section if it doesn't exist
    if ! yq eval '.deploy-keys' $TMP_YAML > /dev/null 2>&1; then
        yq eval -i '.deploy-keys = {}' $TMP_YAML
    fi

    # Store keys using proper multiline format (preserve SSH key structure)
    # Use yq's from_file to preserve exact formatting including newlines
    yq eval -i ".deploy-keys.nix-config = load_str(\"$TEMP_DIR/nix-config-deploy\")" $TMP_YAML
    yq eval -i ".deploy-keys.nix-secrets = load_str(\"$TEMP_DIR/nix-secrets-deploy\")" $TMP_YAML
    yq eval -i ".deploy-keys.chezmoi = load_str(\"$TEMP_DIR/chezmoi-deploy\")" $TMP_YAML

    # Encrypt and save (encrypt in root dir then move to sops/ for creation rule matching)
    mv $TMP_YAML {{HOST}}.yaml
    sops -e -i {{HOST}}.yaml
    mv {{HOST}}.yaml sops/{{HOST}}.yaml

    # Commit the changes
    source {{justfile_directory()}}/scripts/vcs-helpers.sh
    vcs_add sops/{{HOST}}.yaml
    vcs_commit "chore(sops): add deploy keys for {{HOST}}\n\nDatever: $(date +%Y-%m-%d-%H%M)"
    vcs_push
    echo "   ✅ Deploy keys stored in SOPS and committed"

    cd {{justfile_directory()}}
    rm -rf "$TEMP_DIR"

# Helper: Setup and deploy GitHub deploy keys (DEPRECATED - use NixOS module)
_setup-deploy-keys HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔑 Setting up deploy keys for {{HOST}}..."

    # Parse SSH_TARGET to extract port if present
    # Format can be: "root@host" or "root@host -p 22222"
    if [[ "{{SSH_TARGET}}" == *"-p "* ]]; then
        # Extract port
        SCP_PORT=$(echo "{{SSH_TARGET}}" | sed 's/.*-p \([0-9]*\).*/\1/')
        SCP_TARGET=$(echo "{{SSH_TARGET}}" | sed 's/ -p [0-9]*//')
        SCP_PORT_ARG="-P $SCP_PORT"
    else
        SCP_TARGET="{{SSH_TARGET}}"
        SCP_PORT_ARG=""
    fi

    # Check if deploy keys already exist in host SOPS file
    DEPLOY_KEY_EXISTS=$(cd ../nix-secrets && sops -d sops/{{HOST}}.yaml 2>/dev/null | grep -c "deploy-key:" || true)
    if [ -z "$DEPLOY_KEY_EXISTS" ]; then
        DEPLOY_KEY_EXISTS="0"
    fi

    if [ "$DEPLOY_KEY_EXISTS" -eq "0" ]; then
        TEMP_DIR=$(mktemp -d)
        ssh-keygen -t ed25519 -f "$TEMP_DIR/nix-config-deploy" -N "" -C "{{HOST}}-nix-config-deploy" -q
        ssh-keygen -t ed25519 -f "$TEMP_DIR/nix-secrets-deploy" -N "" -C "{{HOST}}-nix-secrets-deploy" -q
        ssh-keygen -t ed25519 -f "$TEMP_DIR/chezmoi-deploy" -N "" -C "{{HOST}}-chezmoi-deploy" -q
        echo "   Adding deploy keys to GitHub..."
        gh repo deploy-key add "$TEMP_DIR/nix-config-deploy.pub" -R fullstopslash/snowflake -t "{{HOST}}-nix-config-deploy"
        gh repo deploy-key add "$TEMP_DIR/nix-secrets-deploy.pub" -R fullstopslash/snowflake-secrets -t "{{HOST}}-nix-secrets-deploy"
        gh repo deploy-key add "$TEMP_DIR/chezmoi-deploy.pub" -R fullstopslash/dotfiles -t "{{HOST}}-chezmoi-deploy"
        echo "   ✅ Deploy keys added to GitHub"

        # Store deploy keys in SOPS using decrypt → modify → encrypt approach
        cd ../nix-secrets
        TMP_YAML=$(mktemp)
        sops -d sops/{{HOST}}.yaml | yq 'del(.sops)' > $TMP_YAML

        # Add deploy-keys section if it doesn't exist
        if ! yq eval '.deploy-keys' $TMP_YAML > /dev/null 2>&1; then
            yq eval -i '.deploy-keys = {}' $TMP_YAML
        fi

        # Store keys using proper multiline format (preserve SSH key structure)
        # Use yq's load_str to preserve exact formatting including newlines
        yq eval -i ".deploy-keys.nix-config = load_str(\"$TEMP_DIR/nix-config-deploy\")" $TMP_YAML
        yq eval -i ".deploy-keys.nix-secrets = load_str(\"$TEMP_DIR/nix-secrets-deploy\")" $TMP_YAML
        yq eval -i ".deploy-keys.chezmoi = load_str(\"$TEMP_DIR/chezmoi-deploy\")" $TMP_YAML

        # Encrypt and save (encrypt in root dir then move to sops/ for creation rule matching)
        mv $TMP_YAML {{HOST}}.yaml
        sops -e -i {{HOST}}.yaml
        mv {{HOST}}.yaml sops/{{HOST}}.yaml

        # Commit the changes
        source {{justfile_directory()}}/scripts/vcs-helpers.sh
        if vcs_has_changes; then
            vcs_commit "chore(sops): add deploy keys for {{HOST}}\n\nDatever: $(date +%Y-%m-%d-%H%M)"
            vcs_push
            echo "   ✅ Deploy keys stored in SOPS and committed"
        fi

        cd {{justfile_directory()}}
        rm -rf "$TEMP_DIR"
    fi

    TEMP_KEY=$(mktemp) && TEMP_KEY_SECRETS=$(mktemp) && TEMP_KEY_CHEZMOI=$(mktemp) && trap "rm -f $TEMP_KEY $TEMP_KEY_SECRETS $TEMP_KEY_CHEZMOI" EXIT
    cd ../nix-secrets && sops -d --extract '["deploy-keys"]["nix-config"]' sops/{{HOST}}.yaml > "$TEMP_KEY" 2>/dev/null && \
    sops -d --extract '["deploy-keys"]["nix-secrets"]' sops/{{HOST}}.yaml > "$TEMP_KEY_SECRETS" 2>/dev/null && \
    sops -d --extract '["deploy-keys"]["chezmoi"]' sops/{{HOST}}.yaml > "$TEMP_KEY_CHEZMOI" 2>/dev/null
    cd {{justfile_directory()}}

    # Deploy keys to root (use scp with -P for port)
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SCP_PORT_ARG "$TEMP_KEY" "$SCP_TARGET:/root/.ssh/nix-config-deploy"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SCP_PORT_ARG "$TEMP_KEY_SECRETS" "$SCP_TARGET:/root/.ssh/nix-secrets-deploy"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SCP_PORT_ARG "$TEMP_KEY_CHEZMOI" "$SCP_TARGET:/root/.ssh/chezmoi-deploy"

    echo "   ✅ Deploy keys configured for {{HOST}}"

# Helper: Rebuild NixOS from cloned config
_rebuild-from-config HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Running system rebuild on {{HOST}}..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{SSH_TARGET}} \
        "if [ -d /persist ]; then \
             USER_HOME=/persist/home/{{PRIMARY_USER}}; \
         else \
             USER_HOME=/home/{{PRIMARY_USER}}; \
         fi && \
         cd \$USER_HOME/nix-config && nixos-rebuild boot --flake .#{{HOST}}"
    echo "   ✅ Rebuild complete"

# Helper: Fix ownership of per-host user age key
_fix-age-key-ownership HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔑 Fixing ownership of user age key..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{SSH_TARGET}} \
        "if [ -d /persist ]; then \
             USER_HOME=/persist/home/{{PRIMARY_USER}}; \
         else \
             USER_HOME=/home/{{PRIMARY_USER}}; \
         fi && \
         if [ -d \$USER_HOME/.config/sops/age ]; then \
             chown -R {{PRIMARY_USER}}:users \$USER_HOME/.config && \
             echo '✅ User age key ownership fixed'; \
         else \
             echo '⚠️  No age key directory found'; \
         fi"

# Helper: Detect home directory based on /persist existence
_detect-home-dir HOST SSH_TARGET PRIMARY_USER:
    #!/usr/bin/env bash
    set -euo pipefail
    # Robustly detect encrypted vs regular hosts and return correct persistent home path
    # Check if user's home is actually at /persist/home (impermanence pattern)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{SSH_TARGET}} \
        "set -e && \
         if [ -d /persist/home/{{PRIMARY_USER}} ] || ([ -d /persist ] && findmnt /home > /dev/null 2>&1); then \
             USER_HOME=/persist/home/{{PRIMARY_USER}} && \
             mkdir -p /persist/home && \
             echo \$USER_HOME; \
         else \
             USER_HOME=/home/{{PRIMARY_USER}} && \
             echo \$USER_HOME; \
         fi"

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

    # Step 1: Pre-generate SSH host keys locally
    echo "🔑 Pre-generating SSH host keys..."

    # Detect if host uses impermanence (check disk layout)
    DISK_LAYOUT=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.disks.layout 2>/dev/null || echo "btrfs")
    HAS_IMPERMANENCE=false
    if [[ "$DISK_LAYOUT" == *"impermanence"* ]]; then
        HAS_IMPERMANENCE=true
        echo "   Detected impermanence layout: $DISK_LAYOUT"
    fi

    # Generate SSH host key in appropriate location
    if [ "$HAS_IMPERMANENCE" = true ]; then
        # For impermanence: generate in /persist/etc/ssh (NixOS looks here)
        mkdir -p "$EXTRA_FILES/persist/etc/ssh"
        ssh-keygen -t ed25519 -f "$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key" -N "" -q
        chmod 600 "$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key"
        chmod 644 "$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key.pub"
        echo "   ✅ SSH host key generated in /persist/etc/ssh (impermanence mode)"
    else
        # For non-impermanence: generate in /etc/ssh (NixOS looks here)
        mkdir -p "$EXTRA_FILES/etc/ssh"
        ssh-keygen -t ed25519 -f "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key" -N "" -q
        chmod 600 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
        chmod 644 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"
        echo "   ✅ SSH host key generated in /etc/ssh (standard mode)"
    fi

    # Step 2: Derive age key from SSH host key
    echo "🔐 Deriving age key from SSH host key..."
    mkdir -p "$EXTRA_FILES/var/lib/sops-nix"

    # Use the correct SSH key path based on impermanence detection
    if [ "$HAS_IMPERMANENCE" = true ]; then
        SSH_KEY_PATH="$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key"
        SSH_PUB_KEY_PATH="$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key.pub"
    else
        SSH_KEY_PATH="$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
        SSH_PUB_KEY_PATH="$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"
    fi

    nix-shell -p ssh-to-age --run "cat $SSH_KEY_PATH | ssh-to-age -private-key" > "$EXTRA_FILES/var/lib/sops-nix/key.txt"
    chmod 600 "$EXTRA_FILES/var/lib/sops-nix/key.txt"

    # Get age public key
    AGE_PUBKEY=$(nix-shell -p ssh-to-age --run "cat $SSH_PUB_KEY_PATH | ssh-to-age")
    echo "   Age public key: $AGE_PUBKEY"

    # Step 2.5: Generate per-host user age key for granular access control
    echo "🔐 Generating per-host user age key..."
    PRIMARY_USER=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.primaryUsername 2>/dev/null || echo "rain")

    # Determine user home based on /persist
    if grep -q "btrfs-luks-impermanence\|bcachefs.*encryption" hosts/{{HOST}}/default.nix 2>/dev/null; then
        USER_AGE_DIR="$EXTRA_FILES/persist/home/$PRIMARY_USER/.config/sops/age"
    else
        USER_AGE_DIR="$EXTRA_FILES/home/$PRIMARY_USER/.config/sops/age"
    fi

    mkdir -p "$USER_AGE_DIR"
    nix-shell -p age --run "age-keygen -o $USER_AGE_DIR/keys.txt" 2>/dev/null
    chmod 600 "$USER_AGE_DIR/keys.txt"

    # Extract public key for .sops.yaml registration
    USER_AGE_PUBKEY=$(nix-shell -p age --run "age-keygen -y $USER_AGE_DIR/keys.txt")
    echo "   User age public key: $USER_AGE_PUBKEY"

    # Step 3: Register age key in nix-secrets and rekey
    just _setup-sops-keys {{HOST}} "$AGE_PUBKEY" "$USER_AGE_PUBKEY" "$PRIMARY_USER"

    # Step 3.75: Generate deploy keys and store in SOPS (NixOS module will deploy them)
    just _generate-deploy-keys {{HOST}}

    # Step 4: Update local flake.lock to get rekeyed secrets and initrd key
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
    echo "✅ nixos-anywhere installation complete! Setting up persisted repos..."
    sleep 10

    # Wait for SSH
    echo "⏳ Waiting for system to boot..."
    for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 root@{{HOST}}.local 'echo ready' >/dev/null 2>&1; then
            echo "✅ System is up!"
            break
        fi
        sleep 2
    done

    # Step 8: Wait for github-repos-init service to clone repos
    echo "⏳ Waiting for repos to be cloned by systemd service..."
    for i in {1..60}; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@{{HOST}}.local \
            "[ -d /home/$PRIMARY_USER/nix-config/.git ] && [ -d /home/$PRIMARY_USER/nix-secrets/.git ] && [ -d /home/$PRIMARY_USER/.local/share/chezmoi/.git ]" 2>/dev/null; then
            echo "✅ All repos cloned successfully"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "⚠️  Timeout waiting for repos - checking service status..."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@{{HOST}}.local \
                "systemctl status github-repos-init" || true
        fi
        sleep 2
    done

    # Step 9: Verify GitHub SSH authentication
    echo "🔐 Verifying GitHub SSH authentication..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@{{HOST}}.local \
        "su - $PRIMARY_USER -c 'ssh -T git@github.com-nix-config 2>&1'" || true

    # Step 10: Rebuild from cloned config
    just _rebuild-from-config {{HOST}} "root@{{HOST}}.local" "$PRIMARY_USER"

    echo ""
    echo "✅ Installation complete!"
    echo "   📁 Repos installed in /home/$PRIMARY_USER:"
    echo "      - nix-config"
    echo "      - nix-secrets"
    echo "      - .local/share/chezmoi"
    echo "   🔑 SSH: ssh root@{{HOST}}.local"
    echo "   ⚠️  Reboot to enable initrd SSH: ssh root@{{HOST}}.local reboot"
    echo ""

# ============================================================================
# VM Testing Workflow
# ============================================================================
# Full workflow: just vm-fresh griefling
# This creates a fresh VM, installs NixOS, sets up secrets, and rebuilds
# ============================================================================

# Helper: Get primary username for a host from flake
_get-vm-primary-user HOST:
    @nix eval --raw .#nixosConfigurations.{{HOST}}.config.identity.primaryUsername

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
        ["anguish"]="22225"
    )

    SSH_PORT="${VM_SSH_PORTS[{{HOST}}]:-22222}"

    # Create temp directory for extra-files
    EXTRA_FILES=$(mktemp -d)
    trap "rm -rf $EXTRA_FILES" EXIT

    # Step 1: Pre-generate SSH host keys locally
    echo "🔑 Pre-generating SSH host keys..."

    # Detect if host uses impermanence (check disk layout)
    DISK_LAYOUT=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.disks.layout 2>/dev/null || echo "btrfs")
    HAS_IMPERMANENCE=false
    if [[ "$DISK_LAYOUT" == *"impermanence"* ]]; then
        HAS_IMPERMANENCE=true
        echo "   Detected impermanence layout: $DISK_LAYOUT"
    fi

    # Generate SSH host key in appropriate location
    if [ "$HAS_IMPERMANENCE" = true ]; then
        # For impermanence: generate in /persist/etc/ssh (NixOS looks here)
        mkdir -p "$EXTRA_FILES/persist/etc/ssh"
        ssh-keygen -t ed25519 -f "$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key" -N "" -q
        chmod 600 "$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key"
        chmod 644 "$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key.pub"
        echo "   ✅ SSH host key generated in /persist/etc/ssh (impermanence mode)"
    else
        # For non-impermanence: generate in /etc/ssh (NixOS looks here)
        mkdir -p "$EXTRA_FILES/etc/ssh"
        ssh-keygen -t ed25519 -f "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key" -N "" -q
        chmod 600 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
        chmod 644 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"
        echo "   ✅ SSH host key generated in /etc/ssh (standard mode)"
    fi

    # Step 2: Derive age key from SSH host key
    echo "🔐 Deriving age key from SSH host key..."
    mkdir -p "$EXTRA_FILES/var/lib/sops-nix"

    # Use the correct SSH key path based on impermanence detection
    if [ "$HAS_IMPERMANENCE" = true ]; then
        SSH_KEY_PATH="$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key"
        SSH_PUB_KEY_PATH="$EXTRA_FILES/persist/etc/ssh/ssh_host_ed25519_key.pub"
    else
        SSH_KEY_PATH="$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
        SSH_PUB_KEY_PATH="$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"
    fi

    nix-shell -p ssh-to-age --run "cat $SSH_KEY_PATH | ssh-to-age -private-key" > "$EXTRA_FILES/var/lib/sops-nix/key.txt"
    chmod 600 "$EXTRA_FILES/var/lib/sops-nix/key.txt"

    # Get age public key
    AGE_PUBKEY=$(nix-shell -p ssh-to-age --run "cat $SSH_PUB_KEY_PATH | ssh-to-age")
    echo "   Age public key: $AGE_PUBKEY"

    # Step 2.5: Generate per-host user age key for granular access control
    echo "🔐 Setting up per-host user age key..."
    PRIMARY_USER=$(just _get-vm-primary-user {{HOST}} 2>/dev/null || echo "rain")

    # Determine user home based on /persist
    if grep -q "btrfs-luks-impermanence\|bcachefs.*encryption" hosts/{{HOST}}/default.nix 2>/dev/null; then
        USER_AGE_DIR="$EXTRA_FILES/persist/home/$PRIMARY_USER/.config/sops/age"
    else
        USER_AGE_DIR="$EXTRA_FILES/home/$PRIMARY_USER/.config/sops/age"
    fi

    mkdir -p "$USER_AGE_DIR"

    # Check if age key already registered in .sops.yaml
    cd ../nix-secrets
    EXISTING_PUBKEY=$(grep "&${PRIMARY_USER}_{{HOST}}" .sops.yaml | grep -oP 'age1\w+' || echo "")
    cd "{{justfile_directory()}}"

    if [ -n "$EXISTING_PUBKEY" ]; then
        echo "   Found registered key: $EXISTING_PUBKEY"
        echo "   Checking for stored private key..."

        # Try to extract private key from SOPS
        cd ../nix-secrets
        EXISTING_PRIVKEY=$(sops -d --extract '["keys"]["age"]' sops/{{HOST}}.yaml 2>/dev/null || echo "")
        cd "{{justfile_directory()}}"

        if [ -n "$EXISTING_PRIVKEY" ]; then
            # Verify private key matches public key
            DERIVED_PUBKEY=$(echo "$EXISTING_PRIVKEY" | nix-shell -p age --run "age-keygen -y" 2>/dev/null || echo "")

            if [ "$DERIVED_PUBKEY" = "$EXISTING_PUBKEY" ]; then
                echo "   ✅ Using existing registered key (verified)"
                echo "$EXISTING_PRIVKEY" > "$USER_AGE_DIR/keys.txt"
                chmod 600 "$USER_AGE_DIR/keys.txt"
                USER_AGE_PUBKEY="$EXISTING_PUBKEY"
            else
                echo "   ⚠️  Private key mismatch - generating fresh key"
                nix-shell -p age --run "age-keygen -o $USER_AGE_DIR/keys.txt" 2>/dev/null
                chmod 600 "$USER_AGE_DIR/keys.txt"
                USER_AGE_PUBKEY=$(nix-shell -p age --run "age-keygen -y $USER_AGE_DIR/keys.txt")
                echo "   New user age public key: $USER_AGE_PUBKEY"
            fi
        else
            echo "   Private key not found in SOPS - generating fresh key"
            nix-shell -p age --run "age-keygen -o $USER_AGE_DIR/keys.txt" 2>/dev/null
            chmod 600 "$USER_AGE_DIR/keys.txt"
            USER_AGE_PUBKEY=$(nix-shell -p age --run "age-keygen -y $USER_AGE_DIR/keys.txt")
            echo "   New user age public key: $USER_AGE_PUBKEY"
        fi
    else
        echo "   No registered key found - generating fresh key"
        nix-shell -p age --run "age-keygen -o $USER_AGE_DIR/keys.txt" 2>/dev/null
        chmod 600 "$USER_AGE_DIR/keys.txt"
        USER_AGE_PUBKEY=$(nix-shell -p age --run "age-keygen -y $USER_AGE_DIR/keys.txt")
        echo "   New user age public key: $USER_AGE_PUBKEY"
    fi

    # Step 3: Register age key in nix-secrets and rekey
    echo "📝 Registering {{HOST}} age key in nix-secrets..."
    just sops-update-host-age-key {{HOST}} "$AGE_PUBKEY"

    # Add per-host user age key for granular access control
    just sops-update-user-age-key $PRIMARY_USER {{HOST}} "$USER_AGE_PUBKEY"

    # Store user private age key in SOPS (if we generated a new one or if mismatch was detected)
    if [ "$DERIVED_PUBKEY" != "$EXISTING_PUBKEY" ] || [ -z "$EXISTING_PRIVKEY" ]; then
        echo "   Storing private age key in SOPS..."
        cd ../nix-secrets
        USER_PRIVKEY=$(cat "$USER_AGE_DIR/keys.txt")

        # Decrypt, update, and re-encrypt using proper SOPS workflow
        # Create a temp file with the right name so SOPS can match creation rules
        TEMP_FILE="/tmp/{{HOST}}.yaml"

        # Decrypt and add/update the private key
        sops -d sops/{{HOST}}.yaml | yq eval '.keys.age = "'"$USER_PRIVKEY"'"' - > "$TEMP_FILE"

        # Re-encrypt using the temp file (SOPS will use creation rules based on filename)
        sops -e "$TEMP_FILE" > sops/{{HOST}}.yaml.new
        mv sops/{{HOST}}.yaml.new sops/{{HOST}}.yaml
        rm -f "$TEMP_FILE"

        echo "   ✅ Private key stored successfully"
        cd "{{justfile_directory()}}"
    fi

    just sops-add-creation-rules $PRIMARY_USER {{HOST}}

    # Rekey all secrets
    echo "   Rekeying secrets..."
    # Rekey all files except chezmoi.yaml (handled separately below)
    cd ../nix-secrets && for file in sops/*.yaml; do \
        # Skip chezmoi.yaml (handled separately with user age key)
        if [[ "$(basename "$file")" == "chezmoi.yaml" ]]; then continue; fi; \
        echo "     Rekeying $file..."; \
        sops updatekeys -y "$file"; \
    done
    # Rekey chezmoi.yaml with user age key (extracted from shared.yaml)
    echo "     Rekeying sops/chezmoi.yaml (with user age key)..."
    sudo cat /var/lib/sops-nix/key.txt > /tmp/malphas-key.txt
    chmod 600 /tmp/malphas-key.txt
    SOPS_AGE_KEY_FILE=/tmp/malphas-key.txt sops -d sops/shared.yaml | yq -r '.["user-keys"]["rain-age-key"]' > /tmp/user-age-key.txt
    SOPS_AGE_KEY_FILE=/tmp/user-age-key.txt sops updatekeys -y sops/chezmoi.yaml
    rm -f /tmp/user-age-key.txt /tmp/malphas-key.txt
    cd "{{justfile_directory()}}"

    # Step 3.5: Stage public key and SOPS-encrypted secrets for commit
    echo "📝 Staging keys in nix-secrets..."
    cd ../nix-secrets
    source {{justfile_directory()}}/scripts/vcs-helpers.sh
    vcs_add "ssh/initrd-public/{{HOST}}_initrd_ed25519.pub"
    cd "{{justfile_directory()}}"

    # Commit and push (includes age keys + SOPS-encrypted initrd keys + rekeyed secrets)
    echo "   Committing and pushing..."
    cd ../nix-secrets && \
        source {{justfile_directory()}}/scripts/vcs-helpers.sh && \
        vcs_add .sops.yaml sops/*.yaml && \
        (vcs_commit "chore: register {{HOST}} age key and rekey secrets" || true) && \
        vcs_push
    cd "{{justfile_directory()}}"

    # Step 3.75: Generate deploy keys and store in SOPS (NixOS module will deploy them)
    just _generate-deploy-keys {{HOST}}

    # Step 4: Update local flake.lock to get rekeyed secrets and initrd key
    echo "📥 Updating local nix-secrets flake input..."
    nix flake update nix-secrets

    # Step 4.1: Commit flake.lock so nixos-anywhere uses correct nix-secrets
    echo "📝 Committing flake.lock update..."
    source {{justfile_directory()}}/scripts/vcs-helpers.sh
    vcs_add flake.lock
    vcs_commit "chore({{HOST}}): update nix-secrets after key registration" || true

    # Step 4.5: Get disk encryption password from SOPS
    echo "🔑 Retrieving disk encryption password from SOPS..."
    source {{HELPERS_PATH}}
    DISKO_PASSWORD=$(sops_get_disk_password {{HOST}})
    if [ -z "$DISKO_PASSWORD" ]; then
        echo "❌ Failed to retrieve disk password from SOPS"
        exit 1
    fi
    echo "   Password retrieved successfully"

    # Step 5: Start VM and run nixos-anywhere with FULL config (no reboot yet)
    echo "🚀 Starting VM and deploying FULL configuration..."
    DISKO_PASSWORD="$DISKO_PASSWORD" ANYWHERE_PHASES="kexec,disko,install" ./scripts/test-fresh-install.sh {{HOST}} --anywhere --force --ssh-port "$SSH_PORT" --extra-files "$EXTRA_FILES"

    # Step 6: Generate TPM token while filesystem is still mounted on installer
    echo ""
    echo "🔐 Generating TPM token during installation..."
    if nix eval .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.enable 2>/dev/null | grep -q "true"; then
        # Evaluate PCR IDs on host before SSH (flake not available on installer)
        PCR_IDS=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.pcrIds 2>/dev/null || echo "0,7")

        # The installer still has /mnt mounted after nixos-anywhere install phase
        # Generate TPM token in the mounted /mnt/persist directory
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" root@127.0.0.1 \
            "bash -c '
                set -euo pipefail
                DISKO_PASSWORD=\"$DISKO_PASSWORD\"
                PERSIST_FOLDER=/mnt/persist
                PCR_IDS=\"$PCR_IDS\"
                TOKEN_PATH=\$PERSIST_FOLDER/etc/clevis/bcachefs-root.jwe

                echo \"Generating Clevis TPM token with PCR IDs: \$PCR_IDS...\"
                mkdir -p \$PERSIST_FOLDER/etc/clevis
                echo \$DISKO_PASSWORD | clevis encrypt tpm2 \"{\\\"pcr_ids\\\":\\\"\$PCR_IDS\\\"}\" > \$TOKEN_PATH
                chmod 600 \$TOKEN_PATH
                echo \"✅ TPM token generated at \$TOKEN_PATH\"
                ls -lh \$TOKEN_PATH
            '"
        echo "✅ TPM token generated successfully"
    else
        echo "⏭️  Skipping TPM token generation (TPM not enabled for {{HOST}})"
    fi

    # Step 7: Reboot the installer to boot into installed system
    echo "🔄 Rebooting into installed system..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" root@127.0.0.1 "reboot" || true

    # Step 8: Wait for system to boot and become available
    echo "⏳ Waiting for system to boot (may take 30-60s for TPM unlock)..."
    sleep 30
    PRIMARY_USER=$(just _get-vm-primary-user {{HOST}} 2>/dev/null || echo "rain")
    for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -p "$SSH_PORT" root@127.0.0.1 'echo ready' >/dev/null 2>&1; then
            echo "✅ System is up!"
            break
        fi
        sleep 2
    done

    # Step 9: Wait for github-repos-init service to clone repos
    echo "⏳ Waiting for repos to be cloned by systemd service..."
    for i in {1..60}; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" root@127.0.0.1 \
            "[ -d /home/$PRIMARY_USER/nix-config/.git ] && [ -d /home/$PRIMARY_USER/nix-secrets/.git ] && [ -d /home/$PRIMARY_USER/.local/share/chezmoi/.git ]" 2>/dev/null; then
            echo "✅ All repos cloned successfully"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "⚠️  Timeout waiting for repos - checking service status..."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" root@127.0.0.1 \
                "systemctl status github-repos-init" || true
        fi
        sleep 2
    done

    # Step 10: Verify GitHub SSH authentication
    echo "🔐 Verifying GitHub SSH authentication..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" root@127.0.0.1 \
        "su - $PRIMARY_USER -c 'ssh -T git@github.com-nix-config 2>&1'" || true

    # Step 11: Rebuild from cloned config
    just _rebuild-from-config {{HOST}} "root@127.0.0.1 -p $SSH_PORT" "$PRIMARY_USER"

    echo ""
    echo "✅ Fresh install complete!"
    echo ""
    echo "   📁 Repos installed in /home/$PRIMARY_USER:"
    echo "      - nix-config"
    echo "      - nix-secrets"
    echo "      - .local/share/chezmoi"
    echo ""
    echo "   🔑 Access:"
    echo "      SSH (root):  ssh -p $SSH_PORT root@127.0.0.1"
    echo "      SSH (user):  ssh -p $SSH_PORT $PRIMARY_USER@127.0.0.1"
    echo "      Display:     just vm-start (SDL with GPU acceleration)"
    echo ""
    echo "   To test remote unlock: just vm-stop {{HOST}} && just vm-start {{HOST}}"

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

    # Add user age key (reuse primary rain user key for test VMs)
    RAIN_AGE_KEY=$(sed -n '4p' ../nix-secrets/.sops.yaml | awk '{print $3}')
    just sops-update-user-age-key rain {{HOST}} "$RAIN_AGE_KEY"

    # Add creation rules if they don't exist (user is 'rain' for test VMs)
    echo "   Ensuring creation rules exist..."
    just sops-add-creation-rules rain {{HOST}}

    # Rekey all secrets to include the new host
    echo "   Rekeying secrets..."
    # Rekey all files except chezmoi.yaml
    cd ../nix-secrets && for file in sops/anguish.yaml sops/griefling.yaml sops/guppy.yaml sops/malphas.yaml sops/shared.yaml sops/sorrow.yaml sops/test-keys.yaml sops/torment.yaml; do \
        echo "     Rekeying $file..."; \
        sops updatekeys -y "$file"; \
    done
    # Rekey chezmoi.yaml with user age key
    echo "     Rekeying sops/chezmoi.yaml (with user age key)..."
    cd ../nix-secrets && \
        USER_KEY=$(sops -d sops/shared.yaml | yq -r '.["user-keys"]["rain-age-key"]') && \
        echo "$USER_KEY" | SOPS_AGE_KEY_FILE=/dev/stdin sops updatekeys -y sops/chezmoi.yaml

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
        echo "   Initrd SSH (for encrypted hosts): ssh -p 2222 root@127.0.0.1"
        echo "   Display: just vm-start (use SDL window)"
    else
        echo "❌ VM {{HOST}} is not running"
    fi

# Start existing VM with GUI (virtio-vga-gl + SDL for hardware acceleration)
vm-start HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu swtpm
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

    # Setup TPM emulation for testing TPM unlock
    TPM_STATE_DIR="quickemu/{{HOST}}-tpm"
    TPM_SOCKET="quickemu/{{HOST}}-tpm.sock"
    mkdir -p "$TPM_STATE_DIR"

    # Clean up any stale TPM socket
    rm -f "$TPM_SOCKET"

    # Start software TPM emulator in background
    swtpm socket \
        --tpmstate dir="$TPM_STATE_DIR" \
        --ctrl type=unixio,path="$TPM_SOCKET" \
        --tpm2 \
        --log level=20 &

    SWTPM_PID=$!
    echo "🔐 TPM emulator started (PID: $SWTPM_PID)"

    # Wait for TPM socket to be ready
    for i in {1..10}; do
        [ -S "$TPM_SOCKET" ] && break
        sleep 0.1
    done

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
        -netdev "user,hostname={{HOST}},hostfwd=tcp::{{VM_SSH_PORT}}-:22,hostfwd=tcp::2222-:2222,id=nic" \
        -chardev socket,id=chrtpm,path="$TPM_SOCKET" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
        -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
        -device virtio-blk-pci,drive=SystemDisk \
        -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" &

    sleep 2
    echo "✅ VM started with SDL display (hardware accelerated + TPM 2.0)"
    echo "   SSH: ssh -p {{VM_SSH_PORT}} root@127.0.0.1"
    echo "   Initrd SSH (for encrypted hosts): ssh -p 2222 root@127.0.0.1"

# Start VM headless (no display, SSH only)
vm-start-headless HOST=DEFAULT_VM_HOST:
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p qemu swtpm
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

    # Setup TPM emulation for testing TPM unlock
    TPM_STATE_DIR="quickemu/{{HOST}}-tpm"
    TPM_SOCKET="quickemu/{{HOST}}-tpm.sock"
    mkdir -p "$TPM_STATE_DIR"

    # Clean up any stale TPM socket
    rm -f "$TPM_SOCKET"

    # Start software TPM emulator in background
    swtpm socket \
        --tpmstate dir="$TPM_STATE_DIR" \
        --ctrl type=unixio,path="$TPM_SOCKET" \
        --tpm2 \
        --log level=20 &

    SWTPM_PID=$!
    echo "🔐 TPM emulator started (PID: $SWTPM_PID)"

    # Wait for TPM socket to be ready
    for i in {1..10}; do
        [ -S "$TPM_SOCKET" ] && break
        sleep 0.1
    done

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
        -netdev "user,hostname={{HOST}},hostfwd=tcp::{{VM_SSH_PORT}}-:22,hostfwd=tcp::2222-:2222,id=nic" \
        -chardev socket,id=chrtpm,path="$TPM_SOCKET" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on" \
        -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
        -device virtio-blk-pci,drive=SystemDisk \
        -drive "id=SystemDisk,if=none,format=qcow2,file=$QCOW2" \
        -daemonize

    echo "✅ VM started (headless + TPM 2.0)"
    echo "   SSH: ssh -p {{VM_SSH_PORT}} root@127.0.0.1"
    echo "   Initrd SSH (for encrypted hosts): ssh -p 2222 root@127.0.0.1"

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

# Generate TPM token for bcachefs encryption using secure SOPS workflow
# Usage:
#   just bcachefs-setup-tpm HOST [DISK_NAME]        # Post-boot (on running system)
#   just bcachefs-setup-tpm HOST bcachefs-root      # Specify disk name
#
# For multi-disk setups:
#   just bcachefs-setup-tpm HOST bcachefs-root
#   just bcachefs-setup-tpm HOST bcachefs-data
#   just bcachefs-setup-tpm HOST bcachefs-backup
#
# Security:
#   - Token MUST be generated on target host (requires physical TPM)
#   - Token is TPM-bound (hardware protection)
#   - Token is SOPS-encrypted in nix-secrets (defense in depth)
#   - Use the Clevis token manager script for all operations
bcachefs-setup-tpm HOST DISK_NAME="bcachefs-root":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if TPM is enabled in host config
    if ! nix eval .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.enable 2>/dev/null | grep -q "true"; then
        echo "❌ TPM unlock not enabled for {{HOST}}"
        echo "   Add 'host.encryption.tpm.enable = true;' to your host configuration"
        exit 1
    fi

    echo "🔐 Generating TPM token for {{HOST}}/{{DISK_NAME}}..."
    echo ""
    echo "IMPORTANT: This command must be run ON the target host ({{HOST}})"
    echo "           TPM token generation requires physical TPM hardware access"
    echo ""

    # Get PCR IDs from host configuration
    PCR_IDS=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.pcrIds 2>/dev/null || echo "0,7")
    echo "📌 Using PCR IDs from config: $PCR_IDS"
    echo ""

    # Source helper functions for SOPS operations
    source {{HELPERS_PATH}}

    # Use the Clevis token manager to generate and SOPS-encrypt the token
    # This handles:
    # 1. Retrieving disk password from SOPS
    # 2. Generating Clevis token bound to TPM
    # 3. Storing token in /persist/etc/clevis/
    # 4. SOPS-encrypting token in nix-secrets
    # 5. Committing and pushing to nix-secrets
    ./scripts/bcachefs-clevis-token-manager.sh generate {{HOST}} {{DISK_NAME}} "$PCR_IDS"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ TPM token setup complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Summary:"
    echo "  - Token generated on {{HOST}} for {{DISK_NAME}}"
    echo "  - TPM binding: PCR $PCR_IDS"
    echo "  - Token location: /persist/etc/clevis/{{DISK_NAME}}.jwe"
    echo "  - SOPS backup: ../nix-secrets/sops/{{HOST}}.yaml"
    echo ""
    echo "Next steps:"
    echo "  1. Update flake:    cd ~/nix-config && nix flake update nix-secrets"
    echo "  2. Rebuild:         sudo nixos-rebuild boot"
    echo "  3. Test unlock:     sudo reboot (should auto-unlock with TPM)"
    echo ""
    echo "For multi-disk setups, repeat with different DISK_NAME:"
    echo "  just bcachefs-setup-tpm {{HOST}} bcachefs-data"
    echo "  just bcachefs-setup-tpm {{HOST}} bcachefs-backup"
    echo ""

# Change LUKS disk password and update SOPS secret
# Interactive workflow: changes device password then syncs to SOPS
# Usage: just luks-rekey [device]
# Example: just luks-rekey /dev/vda2
luks-rekey DEVICE="/dev/mapper/encrypted-nixos":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔐 LUKS Disk Password Re-keying"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This will:"
    echo "  1. Change the LUKS password on {{DEVICE}}"
    echo "  2. Update the SOPS secret (passwords/disk/default)"
    echo "  3. Commit and push changes to nix-secrets"
    echo ""
    echo "⚠️  Make sure you know the current password!"
    echo ""
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    # Check if device exists
    if [ ! -e "{{DEVICE}}" ]; then
        echo "❌ Device {{DEVICE}} not found"
        echo ""
        echo "Available LUKS devices:"
        lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT | grep -E "crypto_LUKS|crypt" || echo "  No LUKS devices found"
        exit 1
    fi

    echo ""
    echo "📊 Device information:"
    cryptsetup luksDump "{{DEVICE}}" | grep -E "Version|UUID|Cipher|Key Slot"
    echo ""

    # Step 1: Change LUKS password
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 1: Change LUKS device password"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "You will be prompted for:"
    echo "  - Current password (from LUKS device)"
    echo "  - New password (enter twice)"
    echo ""

    if ! cryptsetup luksChangeKey "{{DEVICE}}"; then
        echo "❌ Failed to change LUKS password"
        exit 1
    fi

    echo ""
    echo "✅ LUKS password changed successfully!"
    echo ""

    # Step 2: Update SOPS
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 2: Update SOPS secret"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Opening SOPS editor for shared.yaml..."
    echo "Update: passwords.disk.default = <your new password>"
    echo ""
    read -p "Press Enter to open SOPS editor..."

    cd ../nix-secrets
    sops sops/shared.yaml

    echo ""
    echo "✅ SOPS file updated"
    echo ""

    # Step 3: Commit and push
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 3: Commit and push changes"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    source {{justfile_directory()}}/scripts/vcs-helpers.sh
    vcs_add sops/shared.yaml

    if vcs_commit "chore: update disk encryption password"; then
        echo "   Changes committed"
    else
        echo "   No changes to commit (already up to date)"
    fi

    vcs_push
    cd - > /dev/null

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Re-keying complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Summary:"
    echo "  ✅ LUKS device password changed"
    echo "  ✅ SOPS secret updated"
    echo "  ✅ Changes pushed to repository"
    echo ""
    echo "Notes:"
    echo "  - TPM unlock (if enrolled) continues to work"
    echo "  - New password will be used for fresh installs"
    echo "  - Update nix-config flake: nix flake update nix-secrets"
    echo ""
