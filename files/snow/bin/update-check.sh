#!/bin/bash
# Runs once a week (systemd timer): counts the pending updates, for a notification and for Quick Settings.
#   update-check.sh --timer   (waits 60 seconds first, so the panels and notifications are ready)
[ "${1:-}" = "--timer" ] && sleep 60
mkdir -p "$HOME/.cache/snow"
command -v checkupdates >/dev/null || { echo "checkupdates is missing (install pacman-contrib)"; exit 1; }
n=$(checkupdates 2>/dev/null | wc -l)
a=0; command -v yay >/dev/null && a=$(yay -Qua 2>/dev/null | wc -l)
t=$((n + a))
echo "$t" > "$HOME/.cache/snow/updates"
[ "$t" -gt 0 ] && command -v notify-send >/dev/null && \
  notify-send -a snow "Updates available: $t" "Open Super+Tab and press Update. A backup is made automatically before updating."
exit 0
