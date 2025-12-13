#!/usr/bin/env bash

# Get screen dimensions and scale
get_screen_info() {
	screen_resolution=$(hyprctl monitors | grep -A 2 "Monitor" | grep -E "[0-9]+x[0-9]+@" | awk '{print $1}')
	screen_width=$(echo "$screen_resolution" | cut -d'x' -f1)
	screen_height=$(echo "$screen_resolution" | cut -d'x' -f2 | cut -d'@' -f1)
	screen_scale=$(hyprctl monitors | grep "scale:" | awk '{print $2}')

	echo "Screen resolution: $screen_resolution"
	echo "Screen width: $screen_width"
	echo "Screen height: $screen_height"
	echo "Screen scale: $screen_scale"
}

# Get window information
get_window_info() {
	window_info=$(hyprctl activewindow)
	window_class=$(echo "$window_info" | grep "class:" | awk '{print $2}')
	window_title=$(echo "$window_info" | grep "title:" | awk '{$1=""; print $0}' | sed 's/^ *//')
	window_address=$(echo "$window_info" | head -n 1 | cut -f2 -d' ')
	window_fullscreen=$(echo "$window_info" | grep "fullscreen:" | awk '{print $2}')
}

# Toggle floating and pin states (original behavior)
toggle_window_state() {
	hyprctl dispatch togglefloating
	hyprctl dispatch pin
}

# Check if window is both floating and pinned
is_window_floating_and_pinned() {
	window_info=$(hyprctl activewindow)
	is_floating=$(echo "$window_info" | grep "floating:" | awk '{print $2}')
	is_pinned=$(echo "$window_info" | grep "pinned:" | awk '{print $2}')

	[ "$is_floating" = "1" ] && [ "$is_pinned" = "1" ]
}

# Position and resize window
position_window() {
	width="$1"
	height="$2"
	gap_from_right="$3"
	y_pos="$4"

	# Convert scale to integer (2.00 -> 2)
	scale_int=$(echo "$screen_scale" | cut -d'.' -f1)

	# Calculate effective screen width accounting for scale

	effective_width=$((screen_width / scale_int))
	x_pos=$((effective_width - width - gap_from_right))

	echo "Positioning: ${width}x${height} at ($x_pos, $y_pos)"

	hyprctl dispatch resizewindowpixel exact "$width" "$height",address:0x"$window_address"
	hyprctl dispatch movewindowpixel exact "$x_pos" "$y_pos",address:0x"$window_address"
}

# Main execution
main() {
	get_screen_info
	get_window_info
	# If currently fullscreen, don't change state or geometry. Hyprland will
	# restore pinned geometry on un-fullscreen when allow_pin_fullscreen is set.
	if [ "$window_fullscreen" = "1" ]; then
		return 0
	fi

	toggle_window_state

	# Only position when not fullscreen, so allow_pin_fullscreen can restore later
	get_window_info
	if [ "$window_fullscreen" = "0" ] && is_window_floating_and_pinned; then
		case "$window_class" in
		"mpv")
			position_window 640 360 11 39
			;;
		"firefox")
			# Check if it's Picture-in-Picture
			case "$window_title" in
			*"Picture-in-Picture"*)
				position_window 640 360 11 39
				;;
			*)
				position_window 800 600 11 39
				;;
			esac
			;;
		*)
			position_window 640 360 11 39
			;;
		esac
	fi
}

# Run the script
main
