#!/usr/bin/env sh

# SOPS Secrets Manager
# Helper script for managing encrypted secrets

set -e

SECRETS_FILE="secrets.yaml"
SOPS_CONFIG=".sops.yaml"

# Colors for output (POSIX compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    printf '\033[0;32m[INFO]\033[0m %s\n' "$1"
}

print_warning() {
    printf '\033[1;33m[WARNING]\033[0m %s\n' "$1"
}

print_error() {
    printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"
}

print_header() {
    printf '\033[0;34m=== %s ===\033[0m\n' "$1"
}

# Check if SOPS is installed
check_sops() {
    if ! command -v sops >/dev/null 2>&1; then
        print_error "SOPS is not installed. Please install it first."
        exit 1
    fi
}

# Check if age key is available
check_age_key() {
    if ! command -v age >/dev/null 2>&1; then
        print_warning "age is not installed. You may need it for key generation."
    fi
}

# Derive age public key(s) from SSH public key(s)
ssh_to_age() {
    if ! command -v ssh-to-age >/dev/null 2>&1; then
        print_error "ssh-to-age is not installed. Install it to derive age recipients from SSH keys."
        return 1
    fi
    for ssh_pub in "$@"; do
        if [ -f "$ssh_pub" ]; then
            ssh-to-age < "$ssh_pub"
        fi
    done
}

# Initialize SOPS configuration
init_sops() {
    print_header "Initializing SOPS Configuration"
    
    if [ ! -f "$SOPS_CONFIG" ]; then
        print_status "Creating SOPS configuration file..."
        # Collect recipients: primary age key (from local key file if present), optional SSH-derived recipients
        PRIMARY_RECIPIENT="${PRIMARY_RECIPIENT:-}"
        if [ -z "$PRIMARY_RECIPIENT" ] && [ -f "$HOME/.config/sops/age/keys.txt" ] && command -v age-keygen >/dev/null 2>&1; then
            PRIMARY_RECIPIENT=$(age-keygen -y "$HOME/.config/sops/age/keys.txt")
        fi

        HOST_RECIPIENTS=""
        # Derive from common SSH public keys if available
        if command -v ssh-to-age >/dev/null 2>&1; then
            DERIVED=$(ssh_to_age /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || true)
            if [ -n "$DERIVED" ]; then
                HOST_RECIPIENTS="$DERIVED"
            fi
        fi

        USER_SSH_RECIPIENTS=""
        if command -v ssh-to-age >/dev/null 2>&1; then
            DERIVED_USER=$(ssh_to_age "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_rsa.pub" 2>/dev/null || true)
            if [ -n "$DERIVED_USER" ]; then
                USER_SSH_RECIPIENTS="$DERIVED_USER"
            fi
        fi

        cat > "$SOPS_CONFIG" << EOF
# SOPS configuration for NixOS secrets
creation_rules:
  - path_regex: secrets\.yaml$
    age:
$( [ -n "$PRIMARY_RECIPIENT" ] && printf '      - %s\n' "$PRIMARY_RECIPIENT" )
$(printf '%s' "$USER_SSH_RECIPIENTS" | sed 's/^/      - /')
$(printf '%s' "$HOST_RECIPIENTS" | sed 's/^/      - /')
EOF
        print_status "SOPS configuration created at $SOPS_CONFIG"
    else
        print_status "SOPS configuration already exists"
    fi
}

# Encrypt the secrets file
encrypt_secrets() {
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file $SECRETS_FILE does not exist"
        return 1
    fi
    
    print_status "Encrypting $SECRETS_FILE..."
    sops -e -i "$SECRETS_FILE"
    print_status "File encrypted successfully"
}

# Decrypt the secrets file
decrypt_secrets() {
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file $SECRETS_FILE does not exist"
        return 1
    fi
    
    print_status "Decrypting $SECRETS_FILE..."
    sops -d "$SECRETS_FILE"
}

# Edit the encrypted secrets file
edit_secrets() {
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file $SECRETS_FILE does not exist"
        return 1
    fi
    
    print_status "Opening $SECRETS_FILE for editing..."
    sops "$SECRETS_FILE"
}

# Create a new encrypted secrets file
create_secrets_file() {
    if [ -f "$SECRETS_FILE" ]; then
        print_warning "File $SECRETS_FILE already exists"
        printf "Do you want to overwrite it? (y/N): "
        read -r reply
        echo
        case "$reply" in
            [Yy]*) ;;
            *) print_status "Operation cancelled"
               return 1
               ;;
        esac
    fi
    
    print_status "Creating new encrypted secrets file: $SECRETS_FILE"
    
    # Create a template file
    cat > "$SECRETS_FILE" << EOF
# Encrypted secrets for NixOS configuration
# This file contains all sensitive data encrypted with SOPS

# Syncthing device configurations
syncthing:
  devices:
    waterbug:
      id: "YOUR_DEVICE_ID_HERE"
      autoAcceptFolders: true
    pixel:
      id: "YOUR_DEVICE_ID_HERE"
      autoAcceptFolders: true
      introducer: true

# API keys and tokens
api_keys:
  # Add your API keys here
  # example_service: "your_api_key_here"

# Database credentials
databases:
  # Add database credentials here
  # example_db:
  #   host: "localhost"
  #   password: "your_password_here"

# Network configurations
networking:
  # Add network-specific secrets here
  # vpn_credentials:
  #   username: "your_username"
  #   password: "your_password"

# Application secrets
applications:
  # Add application-specific secrets here
  # jellyfin:
  #   api_key: "your_jellyfin_api_key"
EOF
    
    # Encrypt the file
    encrypt_secrets
    print_status "Encrypted secrets file created: $SECRETS_FILE"
}

# Validate the encrypted file
validate_secrets() {
    print_header "Validating Encrypted Secrets"
    
    if [ ! -f "$SECRETS_FILE" ]; then
        print_warning "Secrets file does not exist"
        return 1
    fi
    
    print_status "Validating $SECRETS_FILE..."
    if sops -d "$SECRETS_FILE" >/dev/null 2>&1; then
        print_status "✓ $SECRETS_FILE is valid"
    else
        print_error "✗ $SECRETS_FILE is invalid"
        return 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
SOPS Secrets Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  init                    Initialize SOPS configuration
  encrypt                 Encrypt the secrets file
  decrypt                 Decrypt and display the secrets file
  edit                    Edit the encrypted secrets file
  create                  Create a new encrypted secrets file
  validate                Validate the encrypted secrets file
  help                    Show this help message

Examples:
  $0 init                           # Initialize SOPS setup
  $0 create                        # Create encrypted secrets file
  $0 edit                          # Edit secrets
  $0 validate                      # Validate secrets file

EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        init)
            init_sops
            print_status "SOPS setup complete!"
            ;;
        encrypt)
            encrypt_secrets
            ;;
        decrypt)
            decrypt_secrets
            ;;
        edit)
            edit_secrets
            ;;
        create)
            create_secrets_file
            ;;
        validate)
            validate_secrets
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 
