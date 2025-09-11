#!/usr/bin/env sh

# Host Initialization Script
# Helps set up new hosts with SOPS secrets management

set -e

# Colors for output (POSIX compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if we're on the main development machine
check_main_machine() {
    if [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
        print_error "This script should be run on your main development machine with age keys"
        exit 1
    fi
}

# Export age public key
export_age_key() {
    print_header "Exporting Age Public Key"
    
    if [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
        print_error "Age key file not found at $HOME/.config/sops/age/keys.txt"
        exit 1
    fi
    
    PUBLIC_KEY=$(age-keygen -y "$HOME/.config/sops/age/keys.txt")
    echo "Your age public key: $PUBLIC_KEY"
    echo ""
    echo "Add this to your .sops.yaml on new hosts:"
    echo "age: $PUBLIC_KEY"
}

# Derive age recipient from this host's SSH public key
derive_host_age_recipient() {
    if ! command -v ssh-to-age >/dev/null 2>&1; then
        print_warning "ssh-to-age is not installed; skipping host recipient derivation"
        return 1
    fi
    if [ ! -f "/etc/ssh/ssh_host_ed25519_key.pub" ]; then
        print_warning "SSH host public key not found at /etc/ssh/ssh_host_ed25519_key.pub; skipping"
        return 1
    fi
    ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
}

# Create host-specific secrets template
create_host_secrets() {
    hostname="$1"
    
    if [ -z "$hostname" ]; then
        print_error "Please provide a hostname"
        echo "Usage: $0 create-host-secrets <hostname>"
        exit 1
    fi
    
    print_header "Creating Host-Specific Secrets for $hostname"
    
    # Create host-specific secrets file
    cat > "hosts/$hostname/secrets.yaml" << EOF
# Encrypted secrets for $hostname
# This file contains host-specific sensitive data

# Syncthing device configuration for $hostname
syncthing:
  devices:
    # Add other device IDs here
    # other_device:
    #   id: "YOUR_DEVICE_ID_HERE"
    #   autoAcceptFolders: true

# Host-specific API keys
api_keys:
  # Add host-specific API keys here
  # example_service: "your_api_key_here"

# Host-specific database credentials
databases:
  # Add host-specific database credentials here
  # example_db:
  #   host: "localhost"
  #   password: "your_password_here"

# Host-specific network configurations
networking:
  # Add host-specific network secrets here
  # vpn_credentials:
  #   username: "your_username"
  #   password: "your_password"

# Host-specific application secrets
applications:
  # Add host-specific application secrets here
  # jellyfin:
  #   api_key: "your_jellyfin_api_key"
EOF
    
    print_status "Created host-specific secrets template: hosts/$hostname/secrets.yaml"
    print_warning "You'll need to encrypt this file with SOPS before committing"
}

# Create new host from template
create_new_host() {
    hostname="$1"
    
    if [ -z "$hostname" ]; then
        print_error "Please provide a hostname"
        echo "Usage: $0 create-new-host <hostname>"
        exit 1
    fi
    
    print_header "Creating New Host: $hostname"
    
    # Check if host already exists
    if [ -d "hosts/$hostname" ]; then
        print_error "Host $hostname already exists"
        exit 1
    fi
    
    # Copy template to new host
    print_status "Copying template to hosts/$hostname"
    cp -r hosts/template "hosts/$hostname"
    
    # Update the default.nix file to remove template comments
    sed -i 's/# Template host configuration/# NixOS host configuration for '"$hostname"'/' "hosts/$hostname/default.nix"
    sed -i 's/# Copy this directory and rename it to create a new host//' "hosts/$hostname/default.nix"
    
    print_status "Host $hostname created from template"
    print_status "Next steps:"
    print_status "1. Edit hosts/$hostname/hardware.nix for your hardware"
    print_status "2. Edit hosts/$hostname/default.nix to enable needed roles"
    print_status "3. Run 'nix flake check' to test the configuration"
    print_status "4. Run 'nh os switch --flake .#$hostname' to deploy"
}

# Setup SOPS for new host
setup_new_host() {
    hostname="$1"
    
    if [ -z "$hostname" ]; then
        print_error "Please provide a hostname"
        echo "Usage: $0 setup-new-host <hostname>"
        exit 1
    fi
    
    print_header "Setting up SOPS for new host: $hostname"
    
    # Create host directory if it doesn't exist
    mkdir -p "hosts/$hostname"
    
    # Create host-specific SOPS config
    HOST_RECIPIENT=$(derive_host_age_recipient 2>/dev/null || true)
    PRIMARY_RECIPIENT=""
    if [ -f "$HOME/.config/sops/age/keys.txt" ] && command -v age-keygen >/dev/null 2>&1; then
        PRIMARY_RECIPIENT=$(age-keygen -y "$HOME/.config/sops/age/keys.txt" 2>/dev/null || true)
    fi
    if [ -z "$PRIMARY_RECIPIENT" ] && command -v ssh-to-age >/dev/null 2>&1 && [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        PRIMARY_RECIPIENT=$(ssh-to-age < "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || true)
    fi

    # Write SOPS config with available recipients
    {
        printf '%s\n' "# SOPS configuration for $hostname"
        printf '%s\n' "creation_rules:"
        printf '%s\n' "  - path_regex: secrets\\.yaml$"
        printf '%s\n' "    age:"
        if [ -n "$PRIMARY_RECIPIENT" ]; then
            printf '      - %s\n' "$PRIMARY_RECIPIENT"
        fi
        if [ -n "$HOST_RECIPIENT" ]; then
            printf '      - %s\n' "$HOST_RECIPIENT"
        fi
    } > "hosts/$hostname/.sops.yaml"
    
    # Create host-specific secrets file
    create_host_secrets "$hostname"
    
    print_status "SOPS setup complete for $hostname"
    print_warning "Next steps:"
    echo "1. Edit hosts/$hostname/secrets.yaml with host-specific secrets"
    echo "2. Encrypt the file: sops -e -i hosts/$hostname/secrets.yaml"
    echo "3. Add the host to hosts/default.nix"
    echo "4. Create hosts/$hostname/default.nix with host configuration"
}

# Show usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  export-key                    Export your age public key"
    echo "  create-host-secrets <host>    Create host-specific secrets template"
    echo "  setup-new-host <host>         Setup SOPS for new host"
    echo "  create-new-host <host>        Create new host from template"
    echo "  help                          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 export-key"
    echo "  $0 create-host-secrets myhost"
    echo "  $0 setup-new-host myhost"
    echo "  $0 create-new-host myhost"
}

# Main script logic
main() {
    case "${1:-help}" in
        export-key)
            check_main_machine
            export_age_key
            ;;
        create-host-secrets)
            create_host_secrets "$2"
            ;;
        setup-new-host)
            setup_new_host "$2"
            ;;
        create-new-host)
            create_new_host "$2"
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
