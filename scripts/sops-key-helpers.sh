#!/usr/bin/env bash
# SOPS helper functions for secure key management

# Note: Initrd SSH key functions removed - we now use the same SSH host key
# for both initrd and main system. No separate initrd key management needed.

# Store Clevis token in SOPS
# Usage: sops_store_clevis_token <hostname> <disk_name> <token_file>
# Example: sops_store_clevis_token anguish bcachefs-root /persist/etc/clevis/bcachefs-root.jwe
sops_store_clevis_token() {
    local hostname="$1"
    local disk_name="$2"  # e.g., "bcachefs-root", "bcachefs-data"
    local token_file="$3"
    local sops_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/../nix-secrets"
    local sops_file="${sops_dir}/sops/${hostname}.yaml"
    local temp_yaml="/tmp/sops-clevis-temp-${hostname}.yaml"
    local decrypted_yaml="/tmp/sops-decrypt-${hostname}.yaml"

    if [ ! -f "$token_file" ]; then
        echo "ERROR: Token file not found: $token_file" >&2
        return 1
    fi

    # Read the JWE token (it's JSON) and escape it for YAML
    local token_content
    token_content=$(cat "$token_file" | jq -c .)

    # Check if SOPS file exists
    if [ ! -f "$sops_file" ]; then
        echo "ERROR: SOPS file not found: $sops_file" >&2
        echo "       Create it first during host installation" >&2
        return 1
    fi

    # Decrypt existing file
    sops --decrypt "$sops_file" > "$decrypted_yaml"

    # Use jq to merge the token into the structure
    jq --arg disk "$disk_name" --argjson token "$token_content" \
        '.clevis[$disk].token = $token' \
        "$decrypted_yaml" > "$temp_yaml"

    # Re-encrypt
    (cd "$sops_dir" && sops --encrypt "$temp_yaml" > "sops/${hostname}.yaml")

    # Cleanup
    rm -f "$temp_yaml" "$decrypted_yaml"

    echo "✅ Stored Clevis token for $hostname/$disk_name in SOPS"
}

# Retrieve Clevis token from SOPS
# Usage: sops_get_clevis_token <hostname> <disk_name>
sops_get_clevis_token() {
    local hostname="$1"
    local disk_name="$2"
    local sops_file="../nix-secrets/sops/${hostname}.yaml"

    if [ ! -f "$sops_file" ]; then
        echo "ERROR: SOPS file not found: $sops_file" >&2
        return 1
    fi

    # Extract the token
    sops --extract "[\"clevis\"][\"$disk_name\"][\"token\"]" "$sops_file" 2>/dev/null
}

# Export functions
export -f sops_store_clevis_token
export -f sops_get_clevis_token
