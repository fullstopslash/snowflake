#!/usr/bin/env sh

# Development Workflow Script
# Automates common development tasks for NixOS configuration

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

print_success() {
    printf "${GREEN}✓ %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠ %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}✗ %s${NC}\n" "$1"
}

print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "flake.nix" ]; then
        print_error "Not in a Nix flake directory"
        exit 1
    fi
}

# Run quality checks
run_quality_checks() {
    print_header "Running Quality Checks"
    
    if ./scripts/quality-check.sh; then
        print_success "All quality checks passed"
        return 0
    else
        print_error "Quality checks failed"
        return 1
    fi
}

# Test specific host configuration
test_host() {
    hostname="$1"
    
    if [ -z "$hostname" ]; then
        print_error "Please provide a hostname"
        echo "Usage: $0 test-host <hostname>"
        exit 1
    fi
    
    print_header "Testing Host Configuration: $hostname"
    
    # Check if host exists
    if [ ! -d "hosts/$hostname" ]; then
        print_error "Host $hostname not found"
        exit 1
    fi
    
    # Test the configuration
    if nix eval ".#nixosConfigurations.$hostname.config.system.build.toplevel.drvPath" >/dev/null 2>&1; then
        print_success "Host configuration is valid"
        return 0
    else
        print_error "Host configuration is invalid"
        nix eval ".#nixosConfigurations.$hostname.config.system.build.toplevel.drvPath"
        return 1
    fi
}

# Build and switch to new configuration
build_and_switch() {
    hostname="$1"
    
    if [ -z "$hostname" ]; then
        print_error "Please provide a hostname"
        echo "Usage: $0 build-switch <hostname>"
        exit 1
    fi
    
    print_header "Building and Switching to: $hostname"
    
    # Run quality checks first
    if ! run_quality_checks; then
        print_error "Quality checks failed, aborting build"
        exit 1
    fi
    
    # Test the configuration
    if ! test_host "$hostname"; then
        print_error "Configuration test failed, aborting build"
        exit 1
    fi
    
    # Build and switch
    print_info "Building and switching to new configuration..."
    if nh os switch --flake ".#$hostname"; then
        print_success "Successfully switched to new configuration"
    else
        print_error "Failed to switch to new configuration"
        exit 1
    fi
}

# Create new host
create_host() {
    hostname="$1"
    
    if [ -z "$hostname" ]; then
        print_error "Please provide a hostname"
        echo "Usage: $0 create-host <hostname>"
        exit 1
    fi
    
    print_header "Creating New Host: $hostname"
    
    # Create host from template
    if ./scripts/host-init.sh create-new-host "$hostname"; then
        print_success "Host $hostname created successfully"
        print_info "Next steps:"
        print_info "1. Edit hosts/$hostname/hardware.nix for your hardware"
        print_info "2. Edit hosts/$hostname/default.nix to enable needed roles"
        print_info "3. Run '$0 test-host $hostname' to test the configuration"
        print_info "4. Run '$0 build-switch $hostname' to deploy"
    else
        print_error "Failed to create host $hostname"
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  quality-check                 Run all quality checks"
    echo "  test-host <host>              Test specific host configuration"
    echo "  build-switch <host>           Build and switch to new configuration"
    echo "  create-host <host>            Create new host from template"
    echo "  help                          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 quality-check"
    echo "  $0 test-host malphus"
    echo "  $0 build-switch malphus"
    echo "  $0 create-host newhost"
}

# Main execution
main() {
    check_directory
    
    case "$1" in
        quality-check)
            run_quality_checks
            ;;
        test-host)
            test_host "$2"
            ;;
        build-switch)
            build_and_switch "$2"
            ;;
        create-host)
            create_host "$2"
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

# Run main function
main "$@" 