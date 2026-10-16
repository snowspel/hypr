#!/bin/bash
# usage: killapp.sh name1 name2 ...
tried=""; killed=0
names=()
for n in "$@"; do
  n=$(echo "$n" | tr -cd 'A-Za-z0-9._-')
  [ ${#n} -lt 3 ] && continue
  case "${n,,}" in quickshell|qs|hyprland|systemd|bash|sh|dbus*) continue;; esac
  names+=("$n")
done
for n in "${names[@]}"; do
  tried="$tried $n"
  pkill -u "$USER" -xi -- "$n" && { killed=1; break; }
done
if [ "$killed" = 0 ]; then
  for n in "${names[@]}"; do
    [ ${#n} -lt 4 ] && continue
    for pid in $(pgrep -u "$USER" -fi -- "$n"); do
      [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null && killed=1
    done
    [ "$killed" = 1 ] && break
  done
fi
if [ "$killed" = 1 ]; then notify-send "App closed" "matched:$tried"
else notify-send "Kill failed" "tried:$tried"; fi
