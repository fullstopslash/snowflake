#!/usr/bin/env bash
# KDE theming script for Hyprland

# Set KDE environment variables
export XDG_CURRENT_DESKTOP=KDE
export QT_QPA_PLATFORMTHEME=kde
export QT_STYLE_OVERRIDE=Breeze
export GTK_THEME=Breeze
export XCURSOR_THEME=breeze_cursors
export XCURSOR_SIZE=24

# Apply KDE cursor theme
xsetroot -cursor_name left_ptr

# Apply KDE color scheme if available
if command -v kreadconfig5 >/dev/null 2>&1; then
	KDE_COLOR_SCHEME=$(kreadconfig5 --group "General" --key "ColorScheme" --file ~/.config/kdeglobals)
	if [ -n "$KDE_COLOR_SCHEME" ]; then
		echo "Applied KDE color scheme: $KDE_COLOR_SCHEME"
	fi
fi

echo "KDE theming applied to Hyprland"
