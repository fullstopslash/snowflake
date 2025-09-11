#!/usr/bin/env sh

# Fix Fonts Script
# Temporarily replaces libertinus font family with times in markdown files

set -e

WIKI_DIR="/storage/Documents/wiki"
BACKUP_DIR="/tmp/wiki-font-backup-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -d "$WIKI_DIR" ]; then
        print_error "Wiki directory not found: $WIKI_DIR"
        return 1
    fi
    return 0
}

# Create backup of files with libertinus font
create_backup() {
    print_info "Creating backup of files with libertinus font..."
    mkdir -p "$BACKUP_DIR"
    
    find "$WIKI_DIR" -name "*.md" -exec grep -l "fontfamily: libertinus" {} \; | while read file; do
        cp "$file" "$BACKUP_DIR/"
        print_info "Backed up: $(basename "$file")"
    done
    
    print_success "Backup created in: $BACKUP_DIR"
}

# Replace libertinus with times font
replace_fonts() {
    print_info "Replacing libertinus font family with times..."
    
    find "$WIKI_DIR" -name "*.md" -exec grep -l "fontfamily: libertinus" {} \; | while read file; do
        sed -i 's/fontfamily: libertinus/fontfamily: times/g' "$file"
        print_info "Updated: $(basename "$file")"
    done
    
    print_success "Font replacement completed"
}

# Restore original files
restore_fonts() {
    print_info "Restoring original font settings..."
    
    if [ -d "$BACKUP_DIR" ]; then
        for file in "$BACKUP_DIR"/*.md; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                target="$WIKI_DIR/$filename"
                if [ -f "$target" ]; then
                    cp "$file" "$target"
                    print_info "Restored: $filename"
                fi
            fi
        done
        rm -rf "$BACKUP_DIR"
        print_success "Font settings restored"
    else
        print_warning "No backup found to restore"
    fi
}

# Show help
show_help() {
    cat << EOF
Fix Fonts Script

Usage: $0 [COMMAND]

Commands:
    backup              Create backup of files with libertinus font
    replace             Replace libertinus with times font
    restore             Restore original font settings
    auto                Backup, replace fonts, run make, then restore
    help                Show this help message

Examples:
    $0 backup
    $0 replace
    $0 restore
    $0 auto

The script temporarily replaces the libertinus font family with times
to allow the make command to work with the available TeXLive packages.
EOF
}

# Auto mode: backup, replace, run make, restore
auto_mode() {
    print_info "Running in auto mode..."
    
    if ! check_directory; then
        exit 1
    fi
    
    create_backup
    replace_fonts
    
    print_info "Running make command..."
    cd "$WIKI_DIR"
    if make; then
        print_success "Make completed successfully"
    else
        print_error "Make failed"
    fi
    
    restore_fonts
    print_success "Auto mode completed"
}

# Main script logic
case "${1:-help}" in
    "backup")
        if check_directory; then
            create_backup
        fi
        ;;
    "replace")
        if check_directory; then
            replace_fonts
        fi
        ;;
    "restore")
        if check_directory; then
            restore_fonts
        fi
        ;;
    "auto")
        auto_mode
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        print_info "Run '$0 help' for usage information"
        exit 1
        ;;
esac 