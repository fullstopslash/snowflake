#!/usr/bin/env sh
# Find any media window and toggle fullscreen, remembering pinned position
# Configure media windows in ~/.config/hypr/media-windows.conf
# Dependencies: hyprctl, jq

readonly STATE_FILE="/tmp/hypr_pinned_window_state_${USER}"
readonly FOCUS_FILE="/tmp/hypr_focus_restore_${USER}"
readonly CONFIG_FILE="${HOME}/.config/hypr/media-windows.conf"
readonly DEFAULT_PATTERNS='[
  {"key":"class","val":"mpv"},
  {"key":"title","val":"Picture-in-Picture"},
  {"key":"class","val":"com.github.iwalton3.jellyfin-media-player"},
  {"key":"class","val":"streamlink-twitch-gui"}
]'

# Find media window and extract state (single jq pass)
find_media_window() {
    patterns=$([ -f "$CONFIG_FILE" ] && 
        jq -Rs 'split("\n")|map(select(test("^[^#]")and length>0)|split("=")|{key:.[0],val:.[1]})' "$CONFIG_FILE" ||
        echo "$DEFAULT_PATTERNS")
    
    jq -r --argjson p "$patterns" '
        first(.[]as$c|$p[]as$p|
        if($p.key=="class"and($c.class|test($p.val;"i")))or
           ($p.key=="title"and($c.title|test($p.val;"i")))
        then$c|@sh"addr=\(.address) fs=\(.fullscreen) pin=\(.pinned)"
        else empty end)//empty
    ' <<< "$clients_json"
}

# Save window state (single jq pass)
save_window_state() {
    jq -r '"\(.address)|\(.at[0])|\(.at[1])|\(.size[0])|\(.size[1])|\(.floating)|\(.pinned)"' <<< "$1" > "$STATE_FILE"
}

# Restore window state and focus
restore_window_state() {
    [ ! -f "$STATE_FILE" ] && return 1
    IFS='|' read -r addr x y w h float pin < "$STATE_FILE"
    
    # Batch: focus + fullscreen exit
    hyprctl --batch "dispatch focuswindow address:${addr}; dispatch fullscreen"
    sleep 0.1
    
    # Get current state (single jq, single hyprctl)
    IFS='|' read -r cur_float cur_pin <<< "$(hyprctl clients -j | jq -r ".[]|select(.address==\"${addr}\")|
\"\(.floating)|\(.pinned)\"")"
    
    # Build batch command for restoration
    batch_cmd=""
    [ "$float" = "true" ] && [ "$cur_float" != "true" ] && batch_cmd="dispatch togglefloating address:${addr}"
    
    [ -n "$batch_cmd" ] && { hyprctl --batch "$batch_cmd"; sleep 0.05; }
    
    # Geometry restoration (must be sequential for exact positioning)
    hyprctl dispatch resizewindowpixel "exact $w $h,address:${addr}"
    sleep 0.05
    hyprctl dispatch movewindowpixel "exact $x $y,address:${addr}"
    sleep 0.1
    
    # Re-pin if it was pinned (always pin if saved state says so)
    [ "$pin" = "true" ] && hyprctl dispatch pin "address:${addr}"
    
    # Restore focus from saved file
    [ -f "$FOCUS_FILE" ] && {
        read -r orig < "$FOCUS_FILE"
        [ -n "$orig" ] && [ "$orig" != "$addr" ] && hyprctl dispatch focuswindow "address:${orig}"
        rm -f "$FOCUS_FILE"
    }
    rm -f "$STATE_FILE"
}

# Main execution
main() {
    # Single activewindow call, cache clients
    current_focus=$(hyprctl activewindow -j | jq -r '.address')
    clients_json=$(hyprctl clients -j)
    
    # Find and extract state in one pass
    eval "$(find_media_window)"
    [ -z "$addr" ] && exit 0
    
    if [ "$fs" != "0" ]; then
        # Exiting fullscreen
        restore_window_state
    elif [ "$pin" = "true" ]; then
        # Entering fullscreen from pinned state
        [ "$current_focus" != "$addr" ] && echo "$current_focus" > "$FOCUS_FILE"
        
        # Get full info (already have clients_json cached)
        info=$(jq -r ".[]|select(.address==\"${addr}\")" <<< "$clients_json")
        save_window_state "$info"
        
        # Batch: focus + unpin + fullscreen
        hyprctl --batch "dispatch focuswindow address:${addr}; dispatch pin address:${addr}; dispatch fullscreen address:${addr}"
    else
        # Entering fullscreen from unpinned state
        hyprctl --batch "dispatch focuswindow address:${addr}; dispatch fullscreen"
    fi
}

main
