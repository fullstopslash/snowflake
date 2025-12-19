#!/usr/bin/env bash
# Clevis Token Manager - SOPS-encrypted token management for bcachefs
#
# This script manages Clevis TPM2 tokens for bcachefs disk encryption with SOPS encryption.
# Tokens are TPM-bound for hardware-based protection AND SOPS-encrypted for defense in depth.
#
# Security Architecture:
#   - Tokens are TPM2-bound (can only be decrypted by the specific TPM)
#   - Tokens are also SOPS-encrypted in nix-secrets (defense in depth)
#   - Each disk has its own token (bcachefs-root, bcachefs-data, etc.)
#   - Tokens stored in /persist/etc/clevis/<disk-name>.jwe on host
#   - Tokens also backed up in SOPS at sops/<hostname>.yaml
#
# Integration:
#   - Called from justfile recipes (e.g., just bcachefs-setup-tpm)
#   - Uses SOPS helper functions from sops-key-helpers.sh
#   - Supports per-host, per-disk token management

set -euo pipefail

# Source SOPS helpers
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/sops-key-helpers.sh"
source "$SCRIPT_DIR/helpers.sh"

usage() {
    cat <<EOF
Clevis Token Manager - Manage SOPS-encrypted Clevis tokens for bcachefs

Usage:
    $0 generate <hostname> <disk_name> [<pcr_ids>]
    $0 backup <hostname> <disk_name>
    $0 restore <hostname> <disk_name>
    $0 list <hostname>

Commands:
    generate    Generate new Clevis TPM2 token and SOPS-encrypt it
                - Retrieves disk password from SOPS
                - Generates TPM2-bound JWE token using 'clevis encrypt tpm2'
                - Saves to /persist/etc/clevis/<disk_name>.jwe
                - SOPS-encrypts token in sops/<hostname>.yaml
                - Commits to nix-secrets

    backup      Backup existing token from /persist to SOPS
                - Reads token from /persist/etc/clevis/<disk_name>.jwe
                - SOPS-encrypts and stores in sops/<hostname>.yaml
                - Commits to nix-secrets
                - Use this to backup manually created tokens

    restore     Restore token from SOPS to /persist
                - Retrieves SOPS-encrypted token from sops/<hostname>.yaml
                - Decrypts and writes to /persist/etc/clevis/<disk_name>.jwe
                - Use this after reinstalls or to deploy tokens

    list        List all Clevis tokens for a host
                - Shows all disk names with tokens in SOPS
                - Helps verify which disks have tokens configured

Arguments:
    hostname    Hostname (e.g., anguish, sorrow, griefling)
    disk_name   Disk identifier (e.g., bcachefs-root, bcachefs-data)
    pcr_ids     TPM PCR IDs to bind (default: 0,7)
                - PCR 0: UEFI firmware
                - PCR 7: Secure Boot state
                - Default 0,7 is for Secure Boot enabled systems
                - Use "0" only for non-Secure Boot systems

Examples:
    # Generate token for anguish root filesystem (default PCRs: 0,7)
    $0 generate anguish bcachefs-root

    # Generate token with custom PCR binding (e.g., no Secure Boot)
    $0 generate sorrow bcachefs-data 0

    # Backup existing token to SOPS
    $0 backup anguish bcachefs-root

    # Restore token from SOPS to /persist (e.g., after reinstall)
    $0 restore anguish bcachefs-root

    # List all tokens for a host
    $0 list anguish

Security Architecture:
    - Tokens are SOPS-encrypted in sops/<hostname>.yaml
    - TPM-bound tokens provide hardware-based protection
    - SOPS encryption provides defense in depth (even if token file leaked)
    - Never store tokens in plain text in git
    - Each disk has isolated token (per-disk security)

Per-Disk Token Management:
    Multiple encrypted disks on a host are supported:
      - bcachefs-root: Root filesystem token
      - bcachefs-data: Data partition token
      - bcachefs-backup: Backup volume token

    Generate separate tokens for each disk:
      $0 generate myhost bcachefs-root
      $0 generate myhost bcachefs-data
      $0 generate myhost bcachefs-backup

    Each token is stored in SOPS under clevis/<disk_name>/token

Integration with justfile:
    This script is designed to be called from justfile recipes:
      just bcachefs-setup-tpm <host> [<disk_name>]

    Or directly for manual token management.

PCR Binding Best Practices:
    - Secure Boot enabled: Use PCR 0,7 (default)
      * PCR 0 locks to UEFI firmware
      * PCR 7 locks to Secure Boot state

    - Secure Boot disabled: Use PCR 0 only
      * Avoids token invalidation if Secure Boot toggled

    - WARNING: Tokens become invalid if bound PCRs change
      * Firmware updates may invalidate PCR 0
      * Toggling Secure Boot invalidates PCR 7
      * Keep disk password accessible for recovery!

Workflow Examples:
    1. Fresh install with automatic unlock:
       a) Install system with disk password
       b) After first boot, run: $0 generate anguish bcachefs-root
       c) Rebuild: sudo nixos-rebuild boot
       d) Reboot to test automatic unlock

    2. Backup existing token:
       a) If token exists at /persist/etc/clevis/bcachefs-root.jwe
       b) Run: $0 backup anguish bcachefs-root
       c) Token now SOPS-encrypted in nix-secrets

    3. Restore after reinstall:
       a) Reinstall system with same disk password
       b) Run: $0 restore anguish bcachefs-root
       c) Rebuild: sudo nixos-rebuild boot
       d) Reboot to test automatic unlock

Requirements:
    - Must be run ON the target host (requires physical TPM)
    - clevis and clevis-tpm2 packages must be installed
    - TPM2 must be available and enabled
    - Disk password must exist in SOPS (passwords.disk or shared default)

EOF
    exit 1
}

generate_token() {
    local hostname="$1"
    local disk_name="$2"
    local pcr_ids="${3:-0,7}"

    blue "Generating Clevis TPM token for $hostname/$disk_name"
    echo "  PCR binding: $pcr_ids (default: 0,7 for Secure Boot)"
    echo "  Must be run ON the target host (requires physical TPM)"
    echo ""

    # Get disk password from SOPS
    blue "  Retrieving disk password from SOPS..."
    local disk_password
    disk_password=$(sops_get_disk_password "$hostname")
    if [ -z "$disk_password" ]; then
        red "ERROR: Failed to retrieve disk password from SOPS"
        red "  Make sure the disk password exists in:"
        red "    ../nix-secrets/sops/${hostname}.yaml (passwords.disk)"
        red "  OR"
        red "    ../nix-secrets/sops/shared.yaml (passwords.disk.default)"
        exit 1
    fi
    green "  Disk password retrieved successfully"

    # Determine persist folder path
    local persist_path="/persist"
    local token_path="${persist_path}/etc/clevis/${disk_name}.jwe"

    # Generate token bound to TPM with specified PCRs
    blue "  Generating TPM2-bound JWE token (PCRs: $pcr_ids)..."
    mkdir -p "$(dirname "$token_path")"

    # Use clevis encrypt tpm2 to generate token
    local clevis_error
    if ! clevis_error=$(echo "$disk_password" | clevis encrypt tpm2 "{\"pcr_ids\":\"$pcr_ids\"}" 2>&1 > "$token_path"); then
        red "ERROR: Failed to generate Clevis token"
        red "  Make sure:"
        red "    - This command is run ON the target host (not remotely)"
        red "    - TPM2 is available and enabled in BIOS/UEFI"
        red "    - clevis and clevis-tpm2 packages are installed"
        red "    - You have permissions to access TPM (/dev/tpm0 or /dev/tpmrm0)"
        red "  Error output: $clevis_error"
        exit 1
    fi

    chmod 600 "$token_path"
    green "  Token generated and saved to: $token_path"

    # SOPS-encrypt and store in nix-secrets
    blue "  SOPS-encrypting token for backup..."
    if ! sops_store_clevis_token "$hostname" "$disk_name" "$token_path"; then
        red "ERROR: Failed to SOPS-encrypt token"
        red "  Token is still saved locally at: $token_path"
        red "  You can manually backup later with:"
        red "    $0 backup $hostname $disk_name"
        exit 1
    fi

    # Commit to nix-secrets
    blue "  Committing to nix-secrets..."
    cd "${nix_secrets_dir}"
    source "$SCRIPT_DIR/vcs-helpers.sh"
    vcs_add "sops/${hostname}.yaml"
    if vcs_commit "feat: add Clevis token for $hostname/$disk_name (SOPS-encrypted, PCR $pcr_ids)"; then
        green "  Changes committed to nix-secrets"
        # Try to push, but don't fail if it doesn't work
        if vcs_push; then
            green "  Changes pushed to remote"
        else
            yellow "  Warning: Push failed - you may need to push manually"
        fi
    else
        yellow "  Commit skipped (no changes or already committed)"
    fi

    echo ""
    green "Token generation complete for $hostname/$disk_name"
    echo ""
    blue "Token Details:"
    echo "  - Location: $token_path"
    echo "  - PCR binding: $pcr_ids"
    echo "  - SOPS backup: ../nix-secrets/sops/${hostname}.yaml"
    echo ""
    blue "Next steps:"
    echo "  1. If nix-secrets not pushed, push manually:"
    echo "       cd ../nix-secrets && git push  # (or jj git push)"
    echo "  2. Update nix-config flake:"
    echo "       cd ~/nix-config && nix flake update nix-secrets"
    echo "  3. Rebuild system to include token in initrd:"
    echo "       sudo nixos-rebuild boot"
    echo "  4. Reboot to test automatic TPM unlock:"
    echo "       sudo reboot"
    echo ""
    echo "The system should unlock automatically using the TPM token."
    echo "Keep the disk password accessible for recovery in case TPM state changes!"
}

backup_token() {
    local hostname="$1"
    local disk_name="$2"
    local token_path="/persist/etc/clevis/${disk_name}.jwe"

    blue "Backing up Clevis token for $hostname/$disk_name"
    echo ""

    # Verify token exists
    if [ ! -f "$token_path" ]; then
        red "ERROR: Token not found at $token_path"
        red "  Make sure the token exists before backing up"
        red "  Generate a new token with:"
        red "    $0 generate $hostname $disk_name"
        exit 1
    fi
    green "  Token found at $token_path"

    # SOPS-encrypt and store
    blue "  SOPS-encrypting token..."
    if ! sops_store_clevis_token "$hostname" "$disk_name" "$token_path"; then
        red "ERROR: Failed to SOPS-encrypt token"
        exit 1
    fi

    # Commit to nix-secrets
    blue "  Committing to nix-secrets..."
    cd "${nix_secrets_dir}"
    source "$SCRIPT_DIR/vcs-helpers.sh"
    vcs_add "sops/${hostname}.yaml"
    if vcs_commit "chore: backup Clevis token for $hostname/$disk_name"; then
        green "  Changes committed to nix-secrets"
        if vcs_push; then
            green "  Changes pushed to remote"
        else
            yellow "  Warning: Push failed - you may need to push manually"
        fi
    else
        yellow "  Commit skipped (no changes or already committed)"
    fi

    echo ""
    green "Token backup complete for $hostname/$disk_name"
    echo ""
    echo "Token is now SOPS-encrypted in:"
    echo "  ../nix-secrets/sops/${hostname}.yaml"
    echo ""
    echo "Don't forget to push changes if not already done:"
    echo "  cd ../nix-secrets && git push  # (or jj git push)"
}

restore_token() {
    local hostname="$1"
    local disk_name="$2"
    local token_path="/persist/etc/clevis/${disk_name}.jwe"

    blue "Restoring Clevis token for $hostname/$disk_name"
    echo ""

    # Retrieve from SOPS
    blue "  Retrieving token from SOPS..."
    local token
    token=$(sops_get_clevis_token "$hostname" "$disk_name")
    if [ -z "$token" ]; then
        red "ERROR: Token not found in SOPS for $hostname/$disk_name"
        red "  Checked: ../nix-secrets/sops/${hostname}.yaml"
        red "  Path: clevis.$disk_name.token"
        red ""
        red "Available tokens for this host:"
        list_tokens "$hostname" || true
        exit 1
    fi
    green "  Token retrieved from SOPS"

    # Save to /persist
    blue "  Writing token to: $token_path"
    mkdir -p "$(dirname "$token_path")"
    echo "$token" > "$token_path"
    chmod 600 "$token_path"
    green "  Token restored to /persist"

    echo ""
    green "Token restore complete for $hostname/$disk_name"
    echo ""
    blue "Next steps:"
    echo "  1. Rebuild system to include token in initrd:"
    echo "       sudo nixos-rebuild boot"
    echo "  2. Reboot to test automatic TPM unlock:"
    echo "       sudo reboot"
    echo ""
    echo "The system should unlock automatically using the TPM token."
}

list_tokens() {
    local hostname="$1"
    local sops_file="${nix_secrets_dir}/sops/${hostname}.yaml"

    if [ ! -f "$sops_file" ]; then
        red "ERROR: No SOPS file found for $hostname"
        red "  Expected: $sops_file"
        exit 1
    fi

    blue "Clevis tokens for $hostname:"
    echo ""

    # Extract clevis section if it exists
    local disk_names
    if disk_names=$(sops -d --extract '["clevis"]' "$sops_file" 2>/dev/null | jq -r 'keys[]' 2>/dev/null); then
        if [ -n "$disk_names" ]; then
            echo "$disk_names" | while read -r disk; do
                green "  - $disk"
            done
        else
            yellow "  No Clevis tokens found for $hostname"
        fi
    else
        yellow "  No Clevis tokens found for $hostname"
        echo ""
        echo "  Generate a token with:"
        echo "    $0 generate $hostname <disk_name>"
    fi
    echo ""
}

# Main command dispatcher
case "${1:-}" in
    generate)
        if [ $# -lt 3 ]; then
            red "ERROR: Missing required arguments for 'generate'"
            echo ""
            usage
        fi
        generate_token "$2" "$3" "${4:-0,7}"
        ;;
    backup)
        if [ $# -lt 3 ]; then
            red "ERROR: Missing required arguments for 'backup'"
            echo ""
            usage
        fi
        backup_token "$2" "$3"
        ;;
    restore)
        if [ $# -lt 3 ]; then
            red "ERROR: Missing required arguments for 'restore'"
            echo ""
            usage
        fi
        restore_token "$2" "$3"
        ;;
    list)
        if [ $# -lt 2 ]; then
            red "ERROR: Missing required arguments for 'list'"
            echo ""
            usage
        fi
        list_tokens "$2"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        if [ -n "${1:-}" ]; then
            red "ERROR: Unknown command: $1"
            echo ""
        fi
        usage
        ;;
esac
