#!/usr/bin/env sh

echo "=== Cursor Theme Test ==="
echo "Current XCURSOR_THEME: $XCURSOR_THEME"
echo "Current XCURSOR_SIZE: $XCURSOR_SIZE"

echo ""
echo "Available cursor themes:"
echo "Vector-based cursor themes (similar to Breeze):"
ls /run/current-system/sw/share/icons/ | grep -E "(bibata|capitaine|volantes|catppuccin|nordzy|rose|fuchsia|google|openzone|phinger|breeze|layan|lyra|material|oreo|posy|simp1e|vanilla|whitesur)" | sort

echo ""
echo "To apply cursor theme in current session:"
echo "export XCURSOR_THEME=Bibata-Modern-Classic"
echo "export XCURSOR_SIZE=24"

echo ""
echo "For KDE Plasma, you can also set it via:"
echo "kwriteconfig5 --file ~/.config/kcminputrc --group Mouse --key cursorTheme Bibata-Modern-Classic"
echo "kwriteconfig5 --file ~/.config/kcminputrc --group Mouse --key cursorSize 24"

echo ""
echo "Then restart your KDE session or log out and back in."

