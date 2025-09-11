#!/usr/bin/env sh

# Fix scaling issues for Firefox and Kitty in Hyprland
# This script sets up proper scaling for applications that don't respect system scaling

printf "\033[1;34m🔧 Fixing application scaling issues...\033[0m\n"

# Create Firefox profile directory if it doesn't exist
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
if [ -d "$FIREFOX_PROFILE_DIR" ]; then
    # Find the default profile
    DEFAULT_PROFILE=$(find "$FIREFOX_PROFILE_DIR" -name "*.default*" -type d | head -n 1)
    if [ -n "$DEFAULT_PROFILE" ]; then
        printf "\033[1;32m✓ Found Firefox profile: %s\033[0m\n" "$DEFAULT_PROFILE"
        
        # Create user.js if it doesn't exist
        USER_JS="$DEFAULT_PROFILE/user.js"
        if [ ! -f "$USER_JS" ]; then
            printf "\033[1;33m📝 Creating Firefox user.js for scaling...\033[0m\n"
            cat > "$USER_JS" << 'EOF'
// Firefox scaling settings for HiDPI displays
user_pref("layout.css.devPixelsPerPx", "2.0");
user_pref("ui.textScaleFactor", 200);
user_pref("browser.display.use_document_fonts", 0);
user_pref("browser.zoom.full", false);
user_pref("browser.zoom.siteSpecific", false);
user_pref("browser.zoom.updateBackgroundTabs", false);
user_pref("browser.zoom.disableAnimation", true);
user_pref("widget.wayland", true);
user_pref("widget.use-xdg-desktop-portal", true);
EOF
            printf "\033[1;32m✓ Firefox scaling settings applied\033[0m\n"
        else
            printf "\033[1;33m⚠ Firefox user.js already exists, check manually\033[0m\n"
        fi
    else
        printf "\033[1;31m✗ No Firefox default profile found\033[0m\n"
    fi
else
    printf "\033[1;31m✗ Firefox profile directory not found\033[0m\n"
fi

# Create Kitty config directory if it doesn't exist
KITTY_CONFIG_DIR="$HOME/.config/kitty"
mkdir -p "$KITTY_CONFIG_DIR"

# Create or update kitty.conf
KITTY_CONF="$KITTY_CONFIG_DIR/kitty.conf"
printf "\033[1;33m📝 Updating Kitty configuration for scaling...\033[0m\n"

cat > "$KITTY_CONF" << 'EOF'
# Kitty configuration for HiDPI displays
wayland_titlebar_color system
wayland_enable_ime yes
linux_display_server wayland

# Font settings for HiDPI
font_size 14.0
font_family JetBrains Mono Nerd Font
bold_font auto
italic_font auto
bold_italic_font auto

# Window settings
window_padding_width 10
window_margin_width 0
window_border_width 2
window_border_color #89b4fa

# Tab bar
tab_bar_style powerline
tab_bar_min_tabs 2
tab_bar_edge bottom
tab_bar_align left
tab_powerline_style slanted
tab_title_template "{index}: {title}"

# Colors (Catppuccin Mocha)
background #1e1e2e
foreground #cdd6f4
selection_background #585b70
selection_foreground #cdd6f4
url_color #89b4fa
cursor #cdd6f4

# Tabs
active_tab_background #89b4fa
active_tab_foreground #1e1e2e
inactive_tab_background #313244
inactive_tab_foreground #cdd6f4

# Normal colors
color0 #45475a
color1 #f38ba8
color2 #a6e3a1
color3 #f9e2af
color4 #89b4fa
color5 #f5c2e7
color6 #94e2d5
color7 #bac2de

# Bright colors
color8 #585b70
color9 #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #f5c2e7
color14 #94e2d5
color15 #a6adc8
EOF

printf "\033[1;32m✓ Kitty configuration updated\033[0m\n"

# Check if applications are running and suggest restart
printf "\033[1;34m📋 Next steps:\033[0m\n"
printf "\033[1;33m1. Restart Firefox to apply scaling changes\033[0m\n"
printf "\033[1;33m2. Restart Kitty terminal to apply configuration\033[0m\n"
printf "\033[1;33m3. Restart Waybar: systemctl --user restart waybar\033[0m\n"
printf "\033[1;33m4. If scaling is still off, try: export GDK_SCALE=2 && export QT_SCALE_FACTOR=2\033[0m\n"

printf "\033[1;32m✅ Scaling fix script completed!\033[0m\n"
