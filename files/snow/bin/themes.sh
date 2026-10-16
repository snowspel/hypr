#!/bin/bash
# Data and saving for the Themes menu.
#   themes.sh list             name|mode|bg|surface|accent|text   (one line per theme)
#   themes.sh state            theme|autowall|mode
#   themes.sh get <name>       print the theme JSON
#   themes.sh preview <json>   show these colors now (only theme.json; nothing is saved)
#   themes.sh save <name> <json> [old]   save themes/<name>.json and use it. With [old] (a different name) the old theme is renamed.
D="$HOME/.config/snow"
mode_of() {   # light theme = a dark tint (black overlays); dark theme = a light tint (white overlays)
  local t r g b; t=$(jq -r .tint "$1" 2>/dev/null); t=${t#\#}
  [[ "$t" =~ ^[0-9a-fA-F]{6}$ ]] || { echo dark; return; }
  r=$((16#${t:0:2})); g=$((16#${t:2:2})); b=$((16#${t:4:2}))
  [ $(( (r*299 + g*587 + b*114) / 1000 )) -lt 128 ] && echo light || echo dark
}
KEYS='.bg and .surface and .surfaceHi and .text and .muted and .accent and .warn and .danger and .success and .tint'
case "${1:-list}" in
  list)
    for f in "$D"/themes/*.json; do
      [ -f "$f" ] || continue
      jq -r --arg n "$(basename "$f" .json)" --arg m "$(mode_of "$f")" '[$n,$m,.bg,.surface,.accent,.text]|join("|")' "$f" 2>/dev/null
    done ;;
  state)
    echo "$(cat "$D/theme" 2>/dev/null || echo Snow)|$(cat "$D/autowall" 2>/dev/null || echo off)|$(cat "$D/mode" 2>/dev/null || echo dark)" ;;
  get)
    cat "$D/themes/${2:-}.json" 2>/dev/null ;;
  preview)
    echo "${2:-}" | jq -e "$KEYS" >/dev/null 2>&1 || exit 1
    echo "$2" | jq . > "$D/theme.json.tmp" && cat "$D/theme.json.tmp" > "$D/theme.json"; rm -f "$D/theme.json.tmp" ;;
  save)
    n=$(echo "${2:-}" | tr ' ' '-' | tr -cd 'A-Za-z0-9_-')
    [ -n "$n" ] || { echo "bad theme name"; exit 1; }
    echo "${3:-}" | jq -e "$KEYS" >/dev/null 2>&1 || { echo "bad theme data"; exit 1; }
    mkdir -p "$D/themes"
    old=$(echo "${4:-}" | tr -cd 'A-Za-z0-9_-')
    echo "$3" | jq . > "$D/themes/$n.json" || exit 1
    [ -n "$old" ] && [ "$old" != "$n" ] && rm -f "$D/themes/$old.json"      # rename: remove the old file
    exec bash "$D/bin/switch-theme.sh" set "$n" ;;
esac
