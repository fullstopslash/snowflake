#!/usr/bin/env bash
# SOPS verification script - checks that sops-nix is working correctly
#
# Usage: ./check-sops.sh [--verbose]
#
# Checks:
# 1. Age key exists and is valid format
# 2. Host SSH key exists (for age derivation)
# 3. sops-nix service activated successfully
# 4. Can decrypt secrets (if age key present)

set -eo pipefail

VERBOSE=${1:-}

function info() {
    echo -e "\x1B[34m[*] $1\x1B[0m"
}

function success() {
    echo -e "\x1B[32m[✓] $1\x1B[0m"
}

function error() {
    echo -e "\x1B[31m[✗] $1\x1B[0m"
}

function warn() {
    echo -e "\x1B[33m[!] $1\x1B[0m"
}

errors=0

# Check 1: Host SSH key exists
info "Checking host SSH key..."
if [ -f "/etc/ssh/ssh_host_ed25519_key" ]; then
    success "Host SSH key exists at /etc/ssh/ssh_host_ed25519_key"
    if [ -n "$VERBOSE" ]; then
        pubkey=$(cat /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || echo "unable to read")
        echo "    Public key: ${pubkey:0:50}..."
    fi
else
    error "Host SSH key missing at /etc/ssh/ssh_host_ed25519_key"
    echo "    This key is required for sops age key derivation"
    echo "    Generate with: ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''"
    errors=$((errors + 1))
fi

# Check 2: User age key exists and is valid
info "Checking user age key..."
AGE_KEY_PATH="${HOME}/.config/sops/age/keys.txt"
if [ -f "$AGE_KEY_PATH" ]; then
    if grep -q '^AGE-SECRET-KEY-' "$AGE_KEY_PATH" 2>/dev/null; then
        success "User age key exists and has valid format"
        if [ -n "$VERBOSE" ]; then
            # Show public key derived from secret key
            pubkey=$(age-keygen -y "$AGE_KEY_PATH" 2>/dev/null || echo "unable to derive")
            echo "    Public key: $pubkey"
        fi
    else
        error "Age key file exists but doesn't contain valid AGE-SECRET-KEY"
        errors=$((errors + 1))
    fi
else
    warn "User age key not found at $AGE_KEY_PATH"
    echo "    This is expected on first boot before sops-nix activates"
    echo "    Run 'sudo nixos-rebuild switch' to create it"
fi

# Check 3: sops-nix service status
info "Checking sops-nix activation..."
os=$(uname -s)
if [ "$os" == "Darwin" ]; then
    sops_running=$(launchctl list 2>/dev/null | grep sops || true)
    if [ -n "$sops_running" ]; then
        success "sops-nix service is running (Darwin)"
    else
        warn "sops-nix service not found in launchctl"
    fi
else
    # Check if sops-nix ran recently
    sops_running=$(journalctl --no-pager --no-hostname --since "10 minutes ago" 2>/dev/null | grep "Starting sops-nix activation" || true)
    if [ -z "$sops_running" ]; then
        warn "sops-nix hasn't activated in the last 10 minutes (may be normal)"
    else
        # Check for successful completion
        sops_result=$(journalctl --no-pager --no-hostname --since "10 minutes ago" 2>/dev/null |
            tac |
            awk '!flag; /Starting sops-nix activation/{flag = 1};' |
            tac |
            grep sops || true)

        if [[ $sops_result =~ "Finished sops-nix activation" ]]; then
            success "sops-nix activated successfully"
        else
            error "sops-nix failed to activate"
            echo "    Log output: $sops_result"
            errors=$((errors + 1))
        fi
    fi
fi

# Check 4: Verify decryption works (if we have the age key)
if [ -f "$AGE_KEY_PATH" ] && grep -q '^AGE-SECRET-KEY-' "$AGE_KEY_PATH" 2>/dev/null; then
    info "Checking secret decryption..."
    # Look for any decrypted secret in /run/secrets
    if [ -d "/run/secrets" ]; then
        secret_count=$(find /run/secrets -type f 2>/dev/null | wc -l)
        if [ "$secret_count" -gt 0 ]; then
            success "Found $secret_count decrypted secrets in /run/secrets"
            if [ -n "$VERBOSE" ]; then
                echo "    Secrets:"
                find /run/secrets -type f 2>/dev/null | head -5 | while read -r f; do
                    echo "      - $f"
                done
                if [ "$secret_count" -gt 5 ]; then
                    echo "      ... and $((secret_count - 5)) more"
                fi
            fi
        else
            warn "No secrets found in /run/secrets"
            echo "    This may be normal if no secrets are configured for this host"
        fi
    else
        warn "/run/secrets directory doesn't exist"
        echo "    This is expected before first activation with secrets"
    fi
fi

# Summary
echo
if [ $errors -eq 0 ]; then
    success "All sops checks passed!"
    exit 0
else
    error "$errors check(s) failed"
    exit 1
fi
