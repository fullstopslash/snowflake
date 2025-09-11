#!/usr/bin/env sh

# System Optimization and Maintenance Script
# This script helps monitor and optimize NixOS system performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
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

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script requires root privileges"
        exit 1
    fi
}

# Analyze boot performance
analyze_boot() {
    print_header "Boot Time Analysis"
    
    if command -v systemd-analyze >/dev/null 2>&1; then
        printf "Total boot time: "
        systemd-analyze time 2>/dev/null || print_warning "Could not get boot time"
        
        printf "\nTop 10 slowest services:\n"
        systemd-analyze blame 2>/dev/null | head -10 || print_warning "Could not get service blame"
        
        printf "\nCritical boot chain:\n"
        systemd-analyze critical-chain 2>/dev/null || print_warning "Could not get critical chain"
    else
        print_warning "systemd-analyze not available"
    fi
}

# Analyze kernel modules
analyze_modules() {
    print_header "Kernel Module Analysis"
    
    if [ -f /proc/modules ]; then
        printf "Loaded modules count: "
        lsmod | wc -l
        
        printf "\nLargest modules:\n"
        lsmod | sort -k2 -nr | head -5
        
        printf "\nModule dependencies:\n"
        lsmod | head -3
    else
        print_warning "Could not access /proc/modules"
    fi
}

# Check system resources
check_resources() {
    print_header "System Resources"
    
    # Memory usage
    printf "Memory usage:\n"
    free -h
    
    # Disk usage
    printf "\nDisk usage:\n"
    df -h /
    
    # CPU load
    printf "\nCPU load:\n"
    uptime
}

# Check service status
check_services() {
    print_header "Service Status"
    
    # Check for failed services
    failed_services=$(systemctl --failed --no-legend --no-pager | wc -l)
    if [ "$failed_services" -eq 0 ]; then
        print_success "No failed services"
    else
        print_warning "$failed_services failed service(s)"
        systemctl --failed --no-legend --no-pager
    fi
    
    # Check for long-running services
    printf "\nLong-running services (>30s):\n"
    systemd-analyze blame 2>/dev/null | awk '$1 > 30 {print}' || print_warning "Could not analyze service times"
}

# Optimize system
optimize_system() {
    print_header "System Optimization"
    
    # Clean old generations
    if command -v nh >/dev/null 2>&1; then
        printf "Cleaning old generations...\n"
        nh clean --keep 3
        print_success "Cleaned old generations"
    else
        print_warning "nh not available for cleaning"
    fi
    
    # Optimize Nix store
    if command -v nix-store >/dev/null 2>&1; then
        printf "Optimizing Nix store...\n"
        nix-store --optimise
        print_success "Optimized Nix store"
    else
        print_warning "nix-store not available"
    fi
    
    # Clear systemd journal
    printf "Clearing old journal entries...\n"
    journalctl --vacuum-time=7d
    print_success "Cleared old journal entries"
}

# Check for optimization opportunities
check_optimizations() {
    print_header "Optimization Opportunities"
    
    # Check for unused packages
    printf "Checking for unused packages...\n"
    nix-store --gc --print-roots 2>/dev/null | grep -v "^/nix/var/nix/gcroots" | head -5 || print_warning "Could not check for unused packages"
    
    # Check for large packages
    printf "\nLargest packages in system:\n"
    nix-store --query --requisites /run/current-system | xargs du -sh 2>/dev/null | sort -hr | head -5 || print_warning "Could not analyze package sizes"
    
    # Check for duplicate packages
    printf "\nChecking for duplicate packages...\n"
    nix-store --gc --print-dead 2>/dev/null | wc -l | xargs printf "Dead packages: %s\n" || print_warning "Could not check for dead packages"
}

# Main function
main() {
    printf "${BLUE}NixOS System Optimizer${NC}\n"
    printf "=======================\n\n"
    
    # Check if running as root for some operations
    if [ "$(id -u)" -eq 0 ]; then
        print_success "Running with root privileges"
    else
        print_warning "Some operations require root privileges"
    fi
    
    # Run all analyses
    analyze_boot
    analyze_modules
    check_resources
    check_services
    
    # Only run optimizations if root
    if [ "$(id -u)" -eq 0 ]; then
        optimize_system
    fi
    
    check_optimizations
    
    print_header "Optimization Complete"
    print_success "System analysis and optimization completed"
    printf "\nFor more detailed analysis, see: docs/optimization-guide.md\n"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        printf "Usage: %s [OPTION]\n" "$0"
        printf "Options:\n"
        printf "  --help, -h    Show this help message\n"
        printf "  --boot        Only analyze boot performance\n"
        printf "  --modules     Only analyze kernel modules\n"
        printf "  --resources   Only check system resources\n"
        printf "  --services    Only check service status\n"
        printf "  --optimize    Only run optimizations (requires root)\n"
        exit 0
        ;;
    --boot)
        analyze_boot
        ;;
    --modules)
        analyze_modules
        ;;
    --resources)
        check_resources
        ;;
    --services)
        check_services
        ;;
    --optimize)
        check_root
        optimize_system
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