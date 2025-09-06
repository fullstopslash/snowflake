#!/usr/bin/env sh

# Simple Syncthing secrets cleaner
# This script removes secrets from current files and creates a clean commit

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    printf "\n${BLUE}=== %s ===${NC}\n" "$1"
}

print_success() {
    printf "${GREEN}✓ %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠ %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}✗ %s${NC}\n" "$1"
}

# Remove secrets from current files
remove_secrets() {
    print_header "Removing Syncthing secrets from current files"
    
    # Replace device IDs with placeholders
    find . -name "*.nix" -type f -exec sed -i 's/[REMOVED-DEVICE-ID-1]/[REMOVED-DEVICE-ID-1]/g' {} \;
    find . -name "*.nix" -type f -exec sed -i 's/[REMOVED-DEVICE-ID-2]/[REMOVED-DEVICE-ID-2]/g' {} \;
    
    # Also check other file types
    find . -name "*.yaml" -type f -exec sed -i 's/[REMOVED-DEVICE-ID-1]/[REMOVED-DEVICE-ID-1]/g' {} \;
    find . -name "*.yaml" -type f -exec sed -i 's/[REMOVED-DEVICE-ID-2]/[REMOVED-DEVICE-ID-2]/g' {} \;
    
    find . -name "*.md" -type f -exec sed -i 's/[REMOVED-DEVICE-ID-1]/[REMOVED-DEVICE-ID-1]/g' {} \;
    find . -name "*.md" -type f -exec sed -i 's/[REMOVED-DEVICE-ID-2]/[REMOVED-DEVICE-ID-2]/g' {} \;
    
    print_success "Secrets removed from current files"
}

# Update Syncthing configuration with placeholders
update_syncthing_config() {
    print_header "Updating Syncthing configuration"
    
    # Create a template for Syncthing configuration
    cat > roles/syncthing.nix << 'EOF'
# Syncthing role
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Syncthing configuration
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    settings = {
      devices = {
        # NOTE: Replace with actual device IDs when setting up Syncthing
        "device1" = {
          id = "[REMOVED-DEVICE-ID-1]";  # Replace with actual device ID
          autoAcceptFolders = true;
        };
        "device2" = {
          id = "[REMOVED-DEVICE-ID-2]";  # Replace with actual device ID
          autoAcceptFolders = true;
          introducer = true;
        };
      };
    };
  };

  # Syncthing packages
  environment.systemPackages = with pkgs; [
    syncthingtray
  ];
}
EOF

    print_success "Syncthing configuration updated with placeholders"
}

# Verify secrets are removed
verify_cleaning() {
    print_header "Verifying secrets have been removed"
    
    # Check if secrets still exist
    if grep -r "[REMOVED-DEVICE-ID-1]" . >/dev/null 2>&1; then
        print_warning "Some Syncthing secrets may still exist"
        grep -r "[REMOVED-DEVICE-ID-1]" . || true
    else
        print_success "Syncthing secrets have been removed"
    fi
    
    if grep -r "[REMOVED-DEVICE-ID-2]" . >/dev/null 2>&1; then
        print_warning "Some Syncthing secrets may still exist"
        grep -r "[REMOVED-DEVICE-ID-2]" . || true
    else
        print_success "Syncthing secrets have been removed"
    fi
}

# Create new commit
create_clean_commit() {
    print_header "Creating clean commit"
    
    # Add all changes
    jj add .
    
    # Create commit
    jj commit -m "Remove Syncthing secrets from configuration
    
    - Replaced device IDs with placeholders
    - Updated Syncthing configuration template
    - Added NOTE comments for device ID replacement
    
    This commit removes sensitive Syncthing device IDs from the
    configuration. Replace the placeholder IDs with actual device
    IDs when setting up Syncthing."
    
    print_success "Clean commit created"
}

# Main function
main() {
    printf "${BLUE}Simple Syncthing Secrets Cleaner${NC}\n"
    printf "=====================================\n\n"
    
    print_warning "This will remove Syncthing secrets from current files"
    printf "Make sure you have a backup before proceeding!\n\n"
    
    # Ask for confirmation
    printf "Do you want to proceed? (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            printf "\n"
            ;;
        *)
            print_error "Aborted"
            exit 1
            ;;
    esac
    
    # Remove secrets from current files
    remove_secrets
    
    # Update Syncthing configuration
    update_syncthing_config
    
    # Verify cleaning
    verify_cleaning
    
    # Create clean commit
    create_clean_commit
    
    print_header "Cleaning Complete"
    print_success "Syncthing secrets have been removed from current files"
    printf "\nNext steps:\n"
    printf "1. Replace placeholder device IDs with actual Syncthing device IDs\n"
    printf "2. Test the configuration\n"
    printf "3. Push the cleaned repository\n"
    printf "4. Update any documentation with new device IDs\n"
    printf "\nNote: This only cleans current files. Old commits still contain secrets.\n"
    printf "For complete history cleaning, consider using git filter-branch or BFG.\n"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        printf "Usage: %s [OPTION]\n" "$0"
        printf "Options:\n"
        printf "  --help, -h    Show this help message\n"
        printf "  --verify      Only verify secrets (don't clean)\n"
        exit 0
        ;;
    --verify)
        verify_cleaning
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        printf "Use --help for usage information\n"
        exit 1
        ;;
esac 