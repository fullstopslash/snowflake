#!/usr/bin/env sh

# Fix documents for Tectonic compatibility
# This script removes emoji package usage and fixes SVG references

set -e

WIKI_DIR="/storage/Documents/wiki"

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

# Check if we're in the wiki directory
check_wiki_dir() {
    if [ ! -d "$WIKI_DIR" ]; then
        print_error "Wiki directory not found: $WIKI_DIR"
        return 1
    fi
    return 0
}

# Remove emoji package usage from markdown files
remove_emoji_package() {
    print_info "Removing emoji package usage from markdown files..."
    
    cd "$WIKI_DIR"
    
    # Find files that use emoji package
    find . -name "*.md" -exec grep -l "emoji" {} \; 2>/dev/null | while read file; do
        print_info "Processing: $file"
        
        # Create backup
        cp "$file" "$file.backup"
        
        # Remove emoji package usage
        sed -i '/\\usepackage{emoji}/d' "$file"
        sed -i '/emoji/d' "$file"
        
        print_success "Removed emoji package from: $file"
    done
}

# Fix SVG references
fix_svg_references() {
    print_info "Fixing SVG references..."
    
    cd "$WIKI_DIR"
    
    # Find files that use SVG package
    find . -name "*.md" -exec grep -l "svg" {} \; 2>/dev/null | while read file; do
        print_info "Processing: $file"
        
        # Create backup if not already exists
        if [ ! -f "$file.backup" ]; then
            cp "$file" "$file.backup"
        fi
        
        # Comment out problematic SVG includes
        sed -i 's/\\includesvg{/\\%\\includesvg{/g' "$file"
        
        print_success "Fixed SVG references in: $file"
    done
}

# Fix font specifications for Tectonic
fix_font_specifications() {
    print_info "Fixing font specifications for Tectonic..."
    
    cd "$WIKI_DIR"
    
    # Find files that use libertinus font
    find . -name "*.md" -exec grep -l "fontfamily: libertinus" {} \; 2>/dev/null | while read file; do
        print_info "Processing: $file"
        
        # Create backup if not already exists
        if [ ! -f "$file.backup" ]; then
            cp "$file" "$file.backup"
        fi
        
        # Replace libertinus with a more compatible font
        sed -i 's/fontfamily: libertinus/fontfamily: times/g' "$file"
        
        print_success "Fixed font specification in: $file"
    done
}

# Restore backups
restore_backups() {
    print_info "Restoring original files from backups..."
    
    cd "$WIKI_DIR"
    
    find . -name "*.backup" | while read backup; do
        original="${backup%.backup}"
        if [ -f "$original" ]; then
            cp "$backup" "$original"
            print_success "Restored: $original"
        fi
    done
}

# Show help
show_help() {
    cat << EOF
Usage: $0 <command>

Commands:
    fix-emoji          Remove emoji package usage from markdown files
    fix-svg            Fix SVG references for Tectonic compatibility
    fix-fonts          Fix font specifications for Tectonic
    restore            Restore original files from backups
    all                Apply all fixes
    help               Show this help message

Examples:
    $0 fix-emoji
    $0 fix-svg
    $0 fix-fonts
    $0 all
    $0 restore
EOF
}

# Main script logic
case "${1:-help}" in
    fix-emoji)
        if check_wiki_dir; then
            remove_emoji_package
        fi
        ;;
    fix-svg)
        if check_wiki_dir; then
            fix_svg_references
        fi
        ;;
    fix-fonts)
        if check_wiki_dir; then
            fix_font_specifications
        fi
        ;;
    restore)
        if check_wiki_dir; then
            restore_backups
        fi
        ;;
    all)
        if check_wiki_dir; then
            remove_emoji_package
            fix_svg_references
            fix_font_specifications
            print_success "All fixes applied"
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 