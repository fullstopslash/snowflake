#!/usr/bin/env sh

# Quality Check Script
# Runs all linting tools and provides a comprehensive report

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    printf "\n${BLUE}=== %s ===${NC}\n" "$1"
}

print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
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

# Check if we're in the right directory
check_directory() {
    if [ ! -f "flake.nix" ]; then
        print_error "Not in a Nix flake directory"
        exit 1
    fi
}

# Run nix flake check
run_flake_check() {
    print_header "Running Nix Flake Check"
    
    if nix flake check >/dev/null 2>&1; then
        print_success "Flake check passed"
        return 0
    else
        print_error "Flake check failed"
        nix flake check
        return 1
    fi
}

# Run statix check
run_statix_check() {
    print_header "Running Statix Check"
    
    if statix check >/dev/null 2>&1; then
        print_success "Statix check passed"
        return 0
    else
        print_warning "Statix found issues"
        statix check
        return 1
    fi
}

# Run deadnix check
run_deadnix_check() {
    print_header "Running Deadnix Check"
    
    if deadnix >/dev/null 2>&1; then
        print_success "Deadnix check passed"
        return 0
    else
        print_warning "Deadnix found unused code"
        deadnix
        return 1
    fi
}

# Run alejandra format check
run_format_check() {
    print_header "Checking Code Formatting"
    
    # Check if files need formatting
    if alejandra --check . >/dev/null 2>&1; then
        print_success "Code formatting is correct"
        return 0
    else
        print_warning "Code needs formatting"
        print_info "Run 'alejandra .' to fix formatting"
        return 1
    fi
}

# Check for TODO/FIXME comments
check_todos() {
    print_header "Checking for TODO/FIXME Comments"
    
    # Create a temporary file with the script content excluding itself
    local temp_file=$(mktemp)
    find . -name "*.nix" -o -name "*.md" -o -name "*.sh" | grep -v "scripts/quality-check.sh" > "$temp_file"
    
    local todo_count=0
    todo_count=$(xargs grep -l "TODO:" < "$temp_file" 2>/dev/null | wc -l || echo "0")
    
    if [ "$todo_count" -eq 0 ]; then
        print_success "No TODO/FIXME comments found"
        rm -f "$temp_file"
        return 0
    else
        print_warning "Found $todo_count TODO/FIXME comments"
        xargs grep -l "TODO:" < "$temp_file" 2>/dev/null | while read file; do
            print_info "Found in: $file"
            grep -n "TODO:" "$file" 2>/dev/null || true
        done
        rm -f "$temp_file"
        return 1
    fi
}

# Check for duplicate packages
check_duplicates() {
    print_header "Checking for Duplicate Packages"
    
    local duplicates=0
    duplicates=$(grep -r "environment.systemPackages" . --include="*.nix" | grep -o "with pkgs; \[.*\]" | tr ' ' '\n' | sort | uniq -d | wc -l || echo "0")
    
    if [ "$duplicates" -eq 0 ]; then
        print_success "No obvious duplicate packages found"
        return 0
    else
        print_warning "Found potential duplicate packages"
        return 1
    fi
}

# Main execution
main() {
    print_header "Quality Check Report"
    
    check_directory
    
    local exit_code=0
    
    # Run all checks
    run_flake_check || exit_code=1
    run_statix_check || exit_code=1
    run_deadnix_check || exit_code=1
    run_format_check || exit_code=1
    check_todos || exit_code=1
    check_duplicates || exit_code=1
    
    # Summary
    print_header "Summary"
    if [ $exit_code -eq 0 ]; then
        print_success "All quality checks passed!"
        print_info "Repository is ready for commit"
    else
        print_warning "Some quality checks failed"
        print_info "Please fix the issues above before committing"
    fi
    
    exit $exit_code
}

# Run main function
main "$@" 