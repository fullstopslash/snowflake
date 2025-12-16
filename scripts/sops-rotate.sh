#!/usr/bin/env bash
# SOPS/age key rotation helpers
# Zero-downtime rotation process

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/vcs-helpers.sh"

# Step 1: Generate new age key on host
sops_rotate_generate_new_key() {
	local hostname="${1:?hostname required}"
	local new_key_path="${2:-/tmp/new-age-key.txt}"

	echo "==> Generating new age key for $hostname..."
	ssh "$hostname" "age-keygen -o $new_key_path"

	# Get public key
	local new_pubkey
	new_pubkey=$(ssh "$hostname" "age-keygen -y $new_key_path")

	echo "New public key: $new_pubkey"
	echo "$new_pubkey"
}

# Step 2: Add new key to .sops.yaml (keeping old key)
sops_rotate_add_new_key() {
	local hostname="${1:?hostname required}"
	local new_pubkey="${2:?new public key required}"
	local secrets_dir="${3:-../nix-secrets}"

	echo "==> Adding new key for $hostname to .sops.yaml..."

	cd "$secrets_dir"

	# Add new key with _new suffix
	yq eval ".keys.hosts += [\"&${hostname}_new\", \"$new_pubkey\"]" -i .sops.yaml

	# Add to creation rules (both old and new keys)
	# This is complex - might need manual editing
	echo "Warning: Creation rules may need manual update to include both keys"
	echo "Edit .sops.yaml and add *${hostname}_new to existing creation_rules"

	vcs_add .sops.yaml
	vcs_commit "feat: add new rotation key for $hostname"
}

# Step 3: Rekey all secrets with both old and new keys
sops_rotate_rekey_dual() {
	local secrets_dir="${1:-../nix-secrets}"

	echo "==> Rekeying secrets with both old and new keys..."
	cd "$secrets_dir"

	# Run standard rekey (now includes both keys)
	just rekey
}

# Step 4: Deploy new key to host
sops_rotate_deploy_new_key() {
	local hostname="${1:?hostname required}"
	local new_key_path="${2:-/tmp/new-age-key.txt}"

	echo "==> Deploying new key to $hostname..."

	# Backup old key
	ssh "$hostname" "sudo cp /var/lib/sops-nix/key.txt /var/lib/sops-nix/key.txt.old"

	# Deploy new key
	ssh "$hostname" "sudo tee /var/lib/sops-nix/key.txt > /dev/null" < <(ssh "$hostname" "cat $new_key_path")
	ssh "$hostname" "sudo chmod 600 /var/lib/sops-nix/key.txt"
	ssh "$hostname" "sudo chown root:root /var/lib/sops-nix/key.txt"

	echo "New key deployed. Old key backed up to key.txt.old"
}

# Step 5: Verify new key works
sops_rotate_verify() {
	local hostname="${1:?hostname required}"

	echo "==> Verifying new key works on $hostname..."

	# Rebuild to decrypt with new key
	ssh "$hostname" "sudo nixos-rebuild test"

	# Check sops-nix service
	if ssh "$hostname" "systemctl is-active sops-nix.service" >/dev/null; then
		echo "✓ sops-nix.service is active"
	else
		echo "✗ sops-nix.service failed!"
		return 1
	fi

	# Check secrets exist
	local secret_count
	secret_count=$(ssh "$hostname" "sudo find /run/secrets -type f | wc -l")

	if [ "$secret_count" -gt 0 ]; then
		echo "✓ Secrets decrypted successfully ($secret_count secrets)"
	else
		echo "✗ No secrets found!"
		return 1
	fi

	echo "==> Verification passed!"
}

# Step 6: Remove old key from .sops.yaml
sops_rotate_remove_old_key() {
	local hostname="${1:?hostname required}"
	local secrets_dir="${2:-../nix-secrets}"

	echo "==> Removing old key for $hostname from .sops.yaml..."

	cd "$secrets_dir"

	# This requires manual editing or complex yq
	echo "Warning: Manual step required"
	echo "Edit .sops.yaml and:"
	echo "  1. Remove old &$hostname key line"
	echo "  2. Rename &${hostname}_new to &$hostname"
	echo "  3. Update creation_rules to use renamed anchor"
	echo ""
	echo "Press Enter when done..."
	read -r

	vcs_add .sops.yaml
	vcs_commit "feat: complete rotation for $hostname, remove old key"
}

# Step 7: Final rekey without old key
sops_rotate_final_rekey() {
	local secrets_dir="${1:-../nix-secrets}"

	echo "==> Final rekey with only new key..."
	cd "$secrets_dir"
	just rekey
}

# All-in-one rotation function (interactive)
sops_rotate_host() {
	local hostname="${1:?hostname required}"

	echo "===================================================="
	echo "SOPS Key Rotation for $hostname"
	echo "This is a zero-downtime process with verification"
	echo "===================================================="
	echo ""

	# Step 1
	echo "Step 1/7: Generate new key"
	local new_pubkey
	new_pubkey=$(sops_rotate_generate_new_key "$hostname")
	echo ""

	# Step 2
	echo "Step 2/7: Add new key to .sops.yaml"
	sops_rotate_add_new_key "$hostname" "$new_pubkey"
	echo ""

	# Step 3
	echo "Step 3/7: Rekey with both keys"
	sops_rotate_rekey_dual
	echo ""

	# Step 4
	echo "Step 4/7: Deploy new key to host"
	sops_rotate_deploy_new_key "$hostname"
	echo ""

	# Step 5
	echo "Step 5/7: Verify new key works"
	if ! sops_rotate_verify "$hostname"; then
		echo ""
		echo "ERROR: Verification failed!"
		echo "Rollback: ssh $hostname 'sudo mv /var/lib/sops-nix/key.txt.old /var/lib/sops-nix/key.txt'"
		return 1
	fi
	echo ""

	# Step 6
	echo "Step 6/7: Remove old key from .sops.yaml"
	sops_rotate_remove_old_key "$hostname"
	echo ""

	# Step 7
	echo "Step 7/7: Final rekey"
	sops_rotate_final_rekey
	echo ""

	echo "===================================================="
	echo "Rotation complete for $hostname!"
	echo "Update key metadata:"
	echo "  sops -e -i --set '[\"sops\"][\"key-metadata\"][\"rotated_at\"]' '\"$(date +%Y-%m-%d)\"' ../nix-secrets/sops/$hostname.yaml"
	echo "===================================================="
}
