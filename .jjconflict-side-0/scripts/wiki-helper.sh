#!/usr/bin/env sh

# Wiki Makefile Helper Script
# This script helps manage the wiki Makefile in /storage/Documents/wiki

set -e

WIKI_DIR="/storage/Documents/wiki"
SCRIPT_NAME="wiki-helper"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
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

# Set up environment for LaTeX and document processing
setup_environment() {
    # Add system packages to PATH
    export PATH="/run/current-system/sw/bin:$PATH"
    
    # Set up LaTeX environment variables
    export TEXLIVE_INSTALL_PREFIX="/run/current-system/sw"
    export TEXMFHOME="/run/current-system/sw/share/texmf"
    
    # Create directories if they don't exist
    mkdir -p "$HOME/.cache/texmf"
    mkdir -p "$HOME/.config/texmf"
    
    print_info "Environment set up for document processing"
    print_info "PATH includes: /run/current-system/sw/bin"
    print_info "LaTeX prefix: $TEXLIVE_INSTALL_PREFIX"
}

# Check if storage is mounted
check_storage() {
    if [ ! -d "$WIKI_DIR" ]; then
        print_error "Wiki directory not found: $WIKI_DIR"
        print_info "Make sure the network storage is mounted"
        return 1
    fi
    return 0
}

# Check if required tools are available
check_tools() {
    local missing_tools=()
    
    if ! command -v pandoc >/dev/null 2>&1; then
        missing_tools+=("pandoc")
    fi
    
    if ! command -v make >/dev/null 2>&1; then
        missing_tools+=("make")
    fi
    
    # Check for LaTeX engines
    if ! command -v pdflatex >/dev/null 2>&1; then
        missing_tools+=("pdflatex")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Run: nh os switch .#nixosConfigurations.malphus"
        return 1
    fi
    
    return 0
}

# Show available make targets
show_targets() {
    if ! check_storage; then
        return 1
    fi
    
    print_info "Available make targets:"
    cd "$WIKI_DIR"
    make -n 2>/dev/null | grep -E "^[a-zA-Z][a-zA-Z0-9_-]*:" | sed 's/:.*//' | sort | uniq || {
        print_warning "Could not determine make targets"
        print_info "Try running: make help"
    }
}

# Run make with Tectonic (modern LaTeX compiler)
run_make_tectonic() {
    if ! check_storage || ! check_tools; then
        return 1
    fi
    
    setup_environment
    
    print_info "Running make with Tectonic (modern LaTeX compiler)..."
    cd "$WIKI_DIR"
    
    # Use Tectonic engine
    export PANDOC_LATEX_ENGINE="tectonic"
    
    if [ "$1" = "-n" ]; then
        print_info "Dry run - showing what would be built:"
        make -n "$@"
    else
        make "$@"
    fi
}

# Run make with traditional LaTeX
run_make() {
    if ! check_storage || ! check_tools; then
        return 1
    fi
    
    setup_environment
    
    print_info "Running make with traditional LaTeX compiler..."
    cd "$WIKI_DIR"
    
    # Use traditional LaTeX engine
    export PANDOC_LATEX_ENGINE="pdflatex"
    
    if [ "$1" = "-n" ]; then
        print_info "Dry run - showing what would be built:"
        make -n "$@"
    else
        make "$@"
    fi
}

# Run make with XeLaTeX (better font support)
run_make_xelatex() {
    if ! check_storage || ! check_tools; then
        return 1
    fi
    
    setup_environment
    
    print_info "Running make with XeLaTeX (better font support)..."
    cd "$WIKI_DIR"
    
    # Use XeLaTeX engine for better font support
    export PANDOC_LATEX_ENGINE="xelatex"
    
    if [ "$1" = "-n" ]; then
        print_info "Dry run - showing what would be built:"
        make -n "$@"
    else
        make "$@"
    fi
}

# Run make with font fix (temporary solution)
run_make_fixed() {
    if ! check_storage || ! check_tools; then
        return 1
    fi
    
    setup_environment
    
    print_info "Running make with font fix..."
    cd "$WIKI_DIR"
    
    # Create temporary backup
    BACKUP_DIR="/tmp/wiki-font-backup-$(date +%s)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup files with libertinus font
    find . -name "*.md" -exec grep -l "fontfamily: libertinus" {} \; 2>/dev/null | while read file; do
        cp "$file" "$BACKUP_DIR/"
    done
    
    # Replace libertinus with times font
    find . -name "*.md" -exec grep -l "fontfamily: libertinus" {} \; 2>/dev/null | while read file; do
        sed -i 's/fontfamily: libertinus/fontfamily: times/g' "$file"
    done
    
    # Run make
    if make "$@"; then
        print_success "Make completed successfully"
    else
        print_error "Make failed"
    fi
    
    # Restore original files
    for file in "$BACKUP_DIR"/*.md; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            target="$WIKI_DIR/$filename"
            if [ -f "$target" ]; then
                cp "$file" "$target"
            fi
        fi
    done
    rm -rf "$BACKUP_DIR"
    
    print_success "Font settings restored"
}

# Watch for changes and rebuild
watch_and_rebuild() {
    if ! check_storage || ! check_tools; then
        return 1
    fi
    
    setup_environment
    
    print_info "Watching for changes in $WIKI_DIR..."
    print_info "Press Ctrl+C to stop watching"
    
    cd "$WIKI_DIR"
    
    # Watch for changes in markdown files and rebuild
    find . -name "*.md" -o -name "*.tex" | entr -r make
}

# Show system status
show_status() {
    print_info "=== Wiki Helper Status ==="
    
    # Check storage
    if check_storage; then
        print_success "Storage mounted: $WIKI_DIR"
    else
        print_error "Storage not mounted"
    fi
    
    # Check tools
    if check_tools; then
        print_success "All required tools available"
    else
        print_error "Some tools missing"
    fi
    
    # Check LaTeX engines
    if command -v tectonic >/dev/null 2>&1; then
        print_success "Tectonic available: $(tectonic --version | head -1)"
    else
        print_error "Tectonic not found"
    fi
    
    if command -v pdflatex >/dev/null 2>&1; then
        print_success "PDFLaTeX available: $(pdflatex --version | head -1)"
    else
        print_error "PDFLaTeX not found"
    fi
    
    if command -v xelatex >/dev/null 2>&1; then
        print_success "XeLaTeX available: $(xelatex --version | head -1)"
    else
        print_error "XeLaTeX not found"
    fi
    
    # Check Pandoc
    if command -v pandoc >/dev/null 2>&1; then
        print_success "Pandoc available: $(pandoc --version | head -1)"
    else
        print_error "Pandoc not found"
    fi
    
    # Check Makefile
    if [ -f "$WIKI_DIR/Makefile" ]; then
        print_success "Makefile found"
    else
        print_error "Makefile not found"
    fi
}

# Show help
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
    status              Show system status and tool availability
    targets             Show available make targets
    make [options]      Run make with Tectonic compiler (default)
    make-tectonic       Run make with Tectonic (modern LaTeX compiler)
    make-xelatex        Run make with XeLaTeX (better font support)
    make-fixed          Run make with font fix (temporary solution)
    watch               Watch for changes and rebuild automatically
    help                Show this help message

Examples:
    $SCRIPT_NAME status
    $SCRIPT_NAME targets
    $SCRIPT_NAME make
    $SCRIPT_NAME make -n
    $SCRIPT_NAME make clean
    $SCRIPT_NAME make-tectonic
    $SCRIPT_NAME make-xelatex
    $SCRIPT_NAME make-fixed
    $SCRIPT_NAME watch

Environment:
    Uses Tectonic as default LaTeX compiler
    Automatically sets up environment variables
    Handles storage mount checking
    Provides font fix for problematic documents
EOF
}

# Main script logic
case "${1:-help}" in
    status)
        show_status
        ;;
    targets)
        show_targets
        ;;
    make)
        shift
        run_make_tectonic "$@"
        ;;
    make-tectonic)
        shift
        run_make_tectonic "$@"
        ;;
    make-xelatex)
        shift
        run_make_xelatex "$@"
        ;;
    make-fixed)
        shift
        run_make_fixed "$@"
        ;;
    watch)
        watch_and_rebuild
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        print_info "Run '$SCRIPT_NAME help' for usage information"
        exit 1
        ;;
esac 