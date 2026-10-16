#!/bin/bash
# Makes the hyprlock screen (lock screen) from the theme colors:  ~/.config/hypr/hyprlock.conf
# Background = a blurred picture of your screen. Big 12-hour clock, date, and a password box.
j="$HOME/.config/snow/theme.json"
[ -f "$j" ] || exit 0
c() { jq -r ".$1" "$j" | tr -d '#'; }
mkdir -p "$HOME/.config/hypr"
cat > "$HOME/.config/hypr/hyprlock.conf" << EOT
# made by snow apply-lock.sh (from the theme) - do not edit
general {
    hide_cursor = true
    ignore_empty_input = true
}

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
    brightness = 0.55
}

label {
    monitor =
    text = cmd[update:1000] date +"%-I:%M"
    color = rgb($(c text))
    font_size = 110
    font_family = Inter ExtraBold
    position = 0, 170
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] date +"%p"
    color = rgb($(c accent))
    font_size = 24
    font_family = Inter Bold
    position = 0, 85
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] date +"%A, %B %-d"
    color = rgb($(c muted))
    font_size = 18
    font_family = Inter
    position = 0, 40
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 320, 54
    rounding = 16
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.3
    dots_center = true
    outer_color = rgb($(c accent))
    inner_color = rgb($(c surface))
    font_color = rgb($(c text))
    check_color = rgb($(c accent))
    fail_color = rgb($(c danger))
    capslock_color = rgb($(c warn))
    fade_on_empty = false
    placeholder_text = Password
    fail_text = Wrong password
    position = 0, -60
    halign = center
    valign = center
}
EOT
echo "lock screen updated"
