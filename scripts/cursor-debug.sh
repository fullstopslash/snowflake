#!/usr/bin/env sh

# Cursor Theme Debug Script
# This script helps debug cursor theming issues with stylix

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

print_info "Cursor Theme Debug Script"
print_info "========================="

# Check if we're in a desktop environment
if [ -z "$XDG_CURRENT_DESKTOP" ] && [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
    print_warning "No desktop environment detected"
    print_info "This script is designed to run in a desktop environment"
    exit 1
fi

# Check current cursor theme
print_info "Current cursor theme settings:"
if command -v gsettings >/dev/null 2>&1; then
    CURRENT_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || echo "Not set")
    CURRENT_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null || echo "Not set")
    print_info "  GNOME cursor theme: $CURRENT_THEME"
    print_info "  GNOME cursor size: $CURRENT_SIZE"
else
    print_warning "gsettings not available (not GNOME)"
fi

# Check environment variables
print_info "Environment variables:"
print_info "  XCURSOR_THEME: ${XCURSOR_THEME:-Not set}"
print_info "  XCURSOR_SIZE: ${XCURSOR_SIZE:-Not set}"
print_info "  GTK_CURSOR_THEME_NAME: ${GTK_CURSOR_THEME_NAME:-Not set}"
print_info "  GTK_CURSOR_THEME_SIZE: ${GTK_CURSOR_THEME_SIZE:-Not set}"

# Check available cursor themes
print_info ""
print_info "Available Bibata cursor themes:"
BIBATA_THEMES="Bibata-Modern-Classic Bibata-Modern-Ice Bibata-Modern-Amber Bibata-Original-Classic Bibata-Original-Ice Bibata-Original-Amber"

for theme in $BIBATA_THEMES; do
    if [ -d "/run/current-system/sw/share/icons/$theme" ] || [ -d "$HOME/.local/share/icons/$theme" ] || [ -d "/usr/share/icons/$theme" ]; then
        print_success "  $theme (available)"
    else
        print_warning "  $theme (not found)"
    fi
done

# Check if stylix is configured
print_info ""
print_info "Stylix configuration check:"
if [ -f "/etc/nixos/configuration.nix" ]; then
    if grep -q "stylix" /etc/nixos/configuration.nix; then
        print_success "Stylix found in NixOS configuration"
    else
        print_warning "Stylix not found in NixOS configuration"
    fi
else
    print_warning "NixOS configuration not found"
fi

# Check if cursor packages are installed
print_info ""
print_info "Cursor packages check:"
if nix-store -qR /run/current-system | grep -q "bibata-cursors"; then
    print_success "Bibata cursors package is installed"
else
    print_warning "Bibata cursors package not found in system"
fi

# Provide troubleshooting steps
print_info ""
print_info "Troubleshooting steps:"
print_info "1. If cursor theme is not applying:"
print_info "   - Log out and log back in"
print_info "   - Restart your desktop environment"
print_info "   - Check if stylix is properly configured in your host"

print_info ""
print_info "2. To manually set cursor theme (temporary):"
print_info "   # For GNOME:"
print_info "   gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'"
print_info "   gsettings set org.gnome.desktop.interface cursor-size 24"

print_info ""
print_info "   # For environment variables:"
print_info "   export XCURSOR_THEME='Bibata-Modern-Classic'"
print_info "   export XCURSOR_SIZE=24"

print_info ""
print_info "3. To check if stylix is working:"
print_info "   - Verify your host configuration includes stylix role"
print_info "   - Check that roles.stylix.enable = true"
print_info "   - Ensure cursor.name is set correctly"
print_info "   - Rebuild and switch: nh os switch --flake .#hostname"

print_success "Cursor debug script completed!"

