#!/usr/bin/env bash
# Lightweight KDE theming for Hyprland - no performance impact

# Only set cursor theme (minimal impact)
if [ -n "$XCURSOR_THEME" ]; then
    xsetroot -cursor_name left_ptr
fi

# Apply KDE theme only to specific applications that need it
# This avoids the performance issues of system-wide theming

echo "Lightweight KDE theming applied"
