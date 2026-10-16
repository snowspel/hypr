#!/bin/bash
# Makes kitty colors from theme.json
j="$HOME/.config/snow/theme.json"
c() { jq -r ".$1" "$j"; }
out="$HOME/.config/kitty/snow-theme.conf"
cat > "$out" << EOT
foreground $(c text)
background $(c bg)
selection_foreground $(c bg)
selection_background $(c accent)
cursor $(c accent)
url_color $(c accent)
active_tab_foreground $(c text)
active_tab_background $(c accent)
inactive_tab_foreground $(c muted)
inactive_tab_background $(c surface)
color1 $(c danger)
color2 $(c success)
color3 $(c warn)
color4 $(c accent)
color8 $(c muted)
EOT
if [ "$(cat "$HOME/.config/snow/mode" 2>/dev/null)" = light ]; then
cat >> "$out" << EOT
color0 $(c text)
color7 $(c muted)
color15 $(c text)
EOT
fi
pkill -USR1 kitty 2>/dev/null
echo "kitty theme updated: $out"
