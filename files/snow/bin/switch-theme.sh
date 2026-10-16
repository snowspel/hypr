#!/bin/bash
# One script to change the snow theme.
#   switch-theme.sh toggle | dark | light     Dark <-> Light version of the CURRENT theme
#                                             (wallpaper-colors ON: uses the wallpaper colors)
#   switch-theme.sh set <name>                apply themes/<name>.json  (turns wallpaper-colors OFF)
#   switch-theme.sh auto on|off               wallpaper colors ON / OFF
#   switch-theme.sh --restore                 apply the saved state again (runs at login)
D="$HOME/.config/snow"
rd() { local v; v=$(cat "$D/$1" 2>/dev/null); echo "${v:-$2}"; }
mode=$(rd mode dark); [ "$mode" = light ] || mode=dark
auto=$(rd autowall off); [ "$auto" = on ] || auto=off
name=$(rd theme Snow)
reload=1

mode_of() {   # light theme = a dark tint (black overlays); dark theme = a light tint (white overlays)
  local t r g b; t=$(jq -r .tint "$1" 2>/dev/null); t=${t#\#}
  [[ "$t" =~ ^[0-9a-fA-F]{6}$ ]] || { echo dark; return; }
  r=$((16#${t:0:2})); g=$((16#${t:2:2})); b=$((16#${t:4:2}))
  [ $(( (r*299 + g*587 + b*114) / 1000 )) -lt 128 ] && echo light || echo dark
}

case "${1:-toggle}" in
  toggle)  [ "$mode" = dark ] && mode=light || mode=dark ;;
  dark|light) mode="$1" ;;
  set)     name="${2:-}"; [ -f "$D/themes/$name.json" ] || { echo "theme not found: $name"; exit 1; }
           auto=off; mode=$(mode_of "$D/themes/$name.json") ;;
  auto)    if [ "${2:-}" = on ]; then
             [ "$name" != wallpaper ] && echo "$name" > "$D/theme-before-auto"      # remember the theme to come back to
             auto=on
           else
             auto=off; prev=$(cat "$D/theme-before-auto" 2>/dev/null)
             if [ "$name" != wallpaper ] && [ -f "$D/themes/$name.json" ]; then :
             elif [ -n "$prev" ] && [ -f "$D/themes/$prev.json" ]; then name="$prev"
             else name=Snow; fi
             [ -f "$D/themes/$name.json" ] || { name=$(ls "$D"/themes/*.json 2>/dev/null | head -1 | xargs -r basename -s .json); }
             mode=$(mode_of "$D/themes/$name.json")
           fi ;;
  --restore) reload=0 ;;
  *) echo "use: switch-theme.sh toggle|dark|light|set <name>|auto on|off|--restore"; exit 1 ;;
esac

if [ "$auto" = on ]; then
  src="$D/wallpaper-theme.json"
  python3 "$D/bin/wallpaper-colors.py" "$mode" > "$src.tmp" 2>/dev/null && jq -e . "$src.tmp" >/dev/null 2>&1 \
    && mv "$src.tmp" "$src" || rm -f "$src.tmp"
  [ -f "$src" ] || { auto=off; name="snow-$mode"; }
fi
[ "$auto" = on ] || src="$D/themes/$name.json"
[ -f "$src" ] || { name=Snow; mode=dark; src="$D/themes/Snow.json"; }

# Dark/Light of the current theme: use its pair (snow-dark <-> snow-light) if there is one,
# otherwise build the other version from the same colors.
if [ "$auto" != on ] && [ "$(mode_of "$src")" != "$mode" ]; then
  base=${name%-dark}; base=${base%-light}
  if [ "$base" != "$name" ] && [ -f "$D/themes/$base-$mode.json" ]; then
    name="$base-$mode"; src="$D/themes/$name.json"
  elif python3 "$D/bin/theme-variant.py" "$src" "$mode" > "$D/variant.json.tmp" 2>/dev/null \
       && jq -e . "$D/variant.json.tmp" >/dev/null 2>&1; then
    mv "$D/variant.json.tmp" "$D/variant.json"; src="$D/variant.json"
  else
    rm -f "$D/variant.json.tmp"; mode=$(mode_of "$src")
  fi
fi
[ "$auto" = on ] && name=wallpaper

echo "$mode" > "$D/mode"; echo "$auto" > "$D/autowall"; echo "$name" > "$D/theme"
cat "$src" > "$D/theme.json"          # write into the same file so the panels change at once

# Hyprland border colors
c() { jq -r ".$1" "$src"; }
mix() {  # mix <hex> <percent white> -> hex
  local h=${1#\#} p=$2 r g b
  r=$((16#${h:0:2})); g=$((16#${h:2:2})); b=$((16#${h:4:2}))
  printf '%02x%02x%02x' $((r + (255 - r) * p / 100)) $((g + (255 - g) * p / 100)) $((b + (255 - b) * p / 100))
}
hex6() { local v=${1#\#}; [[ "$v" =~ ^[0-9a-fA-F]{6}$ ]] && echo "$v" || echo "$2"; }   # a wrong color must never reach Hyprland
acc=$(hex6 "$(c accent)" 6366f1); shi=$(hex6 "$(c surfaceHi)" 2a2b3c)
cat > "$HOME/.config/hypr/theme-colors.lua.tmp" << EOT
return {
    active1  = "rgba(${acc}ee)",
    active2  = "rgba($(mix "$acc" 35)ee)",
    inactive = "rgba(${shi}aa)",
    glow     = "rgba(${acc}66)",
}
EOT
mv -f "$HOME/.config/hypr/theme-colors.lua.tmp" "$HOME/.config/hypr/theme-colors.lua"

bash "$D/bin/apply-kitty.sh" >/dev/null 2>&1
bash "$D/bin/apply-gtk.sh"   >/dev/null 2>&1
bash "$D/bin/apply-qt.sh"    >/dev/null 2>&1
bash "$D/bin/apply-lock.sh"  >/dev/null 2>&1
[ "$reload" = 1 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && hyprctl reload >/dev/null 2>&1
echo "theme: $name ($mode)"
