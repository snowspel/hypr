#!/bin/bash
# usage: screenshot.sh <full|region|window> <save|copy>
mode="$1"; save="${2:-save}"
sleep 0.35   # time for the panel to close

dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"
out="$dir/$(date +%F_%H-%M-%S).png"
tmp=$(mktemp --suffix=.png)
trap 'rm -f "$tmp"' EXIT   # no leftover temp file if you cancel
geom=""

case "$mode" in
  region)
    geom=$(slurp) || exit 0
    ;;
  window)
    ws=$(hyprctl -j monitors | jq '[.[].activeWorkspace.id]')
    geom=$(hyprctl -j clients | jq -r --argjson ws "$ws" \
      '.[] | select(.mapped and (.workspace.id as $w | $ws | index($w))) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
      | slurp -r) || exit 0
    ;;
esac

if [ -n "$geom" ]; then
  grim -g "$geom" "$tmp" || { rm -f "$tmp"; exit 1; }
else
  grim "$tmp" || { rm -f "$tmp"; exit 1; }
fi

wl-copy --type image/png < "$tmp"

if [ "$save" = "save" ]; then
  mv "$tmp" "$out"
  notify-send "Screenshot saved" "$out"
else
  rm -f "$tmp"
  notify-send "Screenshot copied to clipboard"
fi
