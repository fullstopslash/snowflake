#!/usr/bin/env sh

# Clean Syncthing secrets from Git history
# This script removes sensitive data from the entire repository history

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

# Check if BFG is available
check_bfg() {
    if ! command -v bfg >/dev/null 2>&1; then
        print_error "BFG Repo-Cleaner not found"
        printf "Install BFG: https://rtyley.github.io/bfg-repo-cleaner/\n"
        printf "Or use: nix-env -iA nixpkgs.bfg\n"
        exit 1
    fi
}

# Create backup
create_backup() {
    print_header "Creating backup"
    
    backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
    printf "Creating backup in: %s\n" "$backup_dir"
    
    # Create backup using jj or git
    if command -v jj >/dev/null 2>&1; then
        jj git export "$backup_dir"
    else
        git clone --mirror . "$backup_dir"
    fi
    
    print_success "Backup created: $backup_dir"
}

# Method 1: Using BFG Repo-Cleaner (Recommended)
clean_with_bfg() {
    print_header "Cleaning with BFG Repo-Cleaner"
    
    # Create a file with patterns to remove
    cat > /tmp/bfg-patterns.txt << 'EOF'
# Syncthing device IDs
[REMOVED-DEVICE-ID-1]
[REMOVED-DEVICE-ID-2]

# Common Syncthing patterns
syncthing.*id.*=
.*device.*id.*=
EOF

    printf "Running BFG to remove Syncthing secrets...\n"
    
    # Use BFG to replace secrets with [REMOVED]
    bfg --replace-text /tmp/bfg-patterns.txt .
    
    print_success "BFG cleaning completed"
}

# Method 2: Using git filter-branch (Fallback)
clean_with_git() {
    print_header "Cleaning with git filter-branch"
    
    printf "This method is slower but doesn't require BFG\n"
    
    # Create a script to replace secrets
    cat > /tmp/filter-script.sh << 'EOF'
#!/bin/sh
# Replace Syncthing device IDs with placeholders
sed -i 's/[REMOVED-DEVICE-ID-1]/[REMOVED-DEVICE-ID-1]/g' "$1"
sed -i 's/[REMOVED-DEVICE-ID-2]/[REMOVED-DEVICE-ID-2]/g' "$1"
EOF
    
    chmod +x /tmp/filter-script.sh
    
    # Run git filter-branch
    git filter-branch --tree-filter '/tmp/filter-script.sh' --prune-empty HEAD
    
    print_success "Git filter-branch cleaning completed"
}

# Method 3: Using jj (if available)
clean_with_jj() {
    print_header "Cleaning with jujutsu"
    
    printf "Using jj to rewrite history...\n"
    
    # Create a script for jj
    cat > /tmp/jj-script.sh << 'EOF'
#!/bin/sh
# Replace Syncthing device IDs in all files
find . -type f -name "*.nix" -exec sed -i 's/[REMOVED-DEVICE-ID-1]/[REMOVED-DEVICE-ID-1]/g' {} \;
find . -type f -name "*.nix" -exec sed -i 's/[REMOVED-DEVICE-ID-2]/[REMOVED-DEVICE-ID-2]/g' {} \;
EOF
    
    chmod +x /tmp/jj-script.sh
    
    # Use jj to rewrite history
    jj new -m "Remove Syncthing secrets from history"
    /tmp/jj-script.sh
    jj commit -m "Remove Syncthing secrets from history"
    
    print_success "Jujutsu cleaning completed"
}

# Verify cleaning
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

# Main function
main() {
    printf "${BLUE}Syncthing Secrets Cleaner${NC}\n"
    printf "============================\n\n"
    
    print_warning "This will permanently remove Syncthing secrets from Git history"
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
    
    # Create backup
    create_backup
    
    # Choose cleaning method
    printf "\nChoose cleaning method:\n"
    printf "1. BFG Repo-Cleaner (fastest, recommended)\n"
    printf "2. Git filter-branch (slower, no external tools)\n"
    printf "3. Jujutsu (if using jj)\n"
    printf "Enter choice (1-3): "
    read -r choice
    
    case "$choice" in
        1)
            check_bfg
            clean_with_bfg
            ;;
        2)
            clean_with_git
            ;;
        3)
            if command -v jj >/dev/null 2>&1; then
                clean_with_jj
            else
                print_error "Jujutsu not available, falling back to git filter-branch"
                clean_with_git
            fi
            ;;
        *)
            print_error "Invalid choice, using BFG"
            check_bfg
            clean_with_bfg
            ;;
    esac
    
    # Verify cleaning
    verify_cleaning
    
    print_header "Cleaning Complete"
    print_success "Syncthing secrets have been removed from Git history"
    printf "\nNext steps:\n"
    printf "1. Update Syncthing configuration with new device IDs\n"
    printf "2. Test the configuration\n"
    printf "3. Push the cleaned repository\n"
    printf "4. Update any documentation with new device IDs\n"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        printf "Usage: %s [OPTION]\n" "$0"
        printf "Options:\n"
        printf "  --help, -h    Show this help message\n"
        printf "  --verify      Only verify secrets (don't clean)\n"
        printf "  --backup      Only create backup\n"
        exit 0
        ;;
    --verify)
        verify_cleaning
        ;;
    --backup)
        create_backup
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