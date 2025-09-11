#!/usr/bin/env sh

# Stylix Setup Helper Script
# This script helps you set up stylix theming for your NixOS hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    printf "${BLUE}ℹ ${NC}%s\n" "$1"
}

print_success() {
    printf "${GREEN}✓ ${NC}%s\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠ ${NC}%s\n" "$1"
}

print_error() {
    printf "${RED}✗ ${NC}%s\n" "$1"
}

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
    print_error "This script must be run from the root of your NixOS repository"
    exit 1
fi

print_info "Stylix Setup Helper"
print_info "==================="

# Check if stylix is already added to flake.nix
if grep -q "stylix" flake.nix; then
    print_success "Stylix is already added to flake.nix"
else
    print_warning "Stylix is not found in flake.nix. Please add it first."
    exit 1
fi

# Check if stylix role exists
if [ -f "roles/stylix.nix" ]; then
    print_success "Stylix role found at roles/stylix.nix"
else
    print_error "Stylix role not found. Please create roles/stylix.nix first."
    exit 1
fi

# Create wallpapers directory if it doesn't exist
if [ ! -d "assets/wallpapers" ]; then
    print_info "Creating assets/wallpapers directory..."
    mkdir -p assets/wallpapers
    print_success "Created assets/wallpapers directory"
fi

# Create schemes directory if it doesn't exist
if [ ! -d "schemes" ]; then
    print_info "Creating schemes directory..."
    mkdir -p schemes
    print_success "Created schemes directory"
fi

print_info ""
print_info "Available themes:"
print_info "  • catppuccin-mocha (dark)"
print_info "  • catppuccin-macchiato (medium)"
print_info "  • catppuccin-frappe (medium-light)"
print_info "  • catppuccin-latte (light)"
print_info "  • dracula"
print_info "  • gruvbox-dark"
print_info "  • gruvbox-light"
print_info "  • nord"
print_info "  • tokyonight"
print_info "  • rose-pine"
print_info "  • everforest"
print_info "  • kanagawa"
print_info "  • onedark"
print_info "  • solarized-dark"
print_info "  • solarized-light"
print_info "  • custom (use your own base16 scheme)"

print_info ""
print_info "To add stylix to a host:"
print_info "1. Add 'imports = [ ../../roles/stylix.nix ];' to your host configuration"
print_info "2. Add stylix configuration:"
print_info ""
print_info "   roles.stylix = {"
print_info "     enable = true;"
print_info "     theme = \"catppuccin-mocha\";"
print_info "     wallpaper = ../../assets/wallpapers/your-wallpaper.jpg;"
print_info "   };"
print_info ""
print_info "3. Place your wallpaper in assets/wallpapers/"
print_info "4. Run 'nix flake check' to validate"
print_info "5. Build and switch: 'nh os switch --flake .#hostname'"

print_info ""
print_info "For more details, see:"
print_info "  • roles/stylix.md - Detailed documentation"
print_info "  • examples/stylix-example.nix - Example configuration"
print_info "  • schemes/example-custom.yaml - Custom theme example"

print_success "Stylix setup helper completed!"


