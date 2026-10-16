#!/bin/bash
# Power settings: screen off / lock / sleep after N minutes without keyboard or mouse (0 = Never).
# It writes ~/.config/hypr/hypridle.conf and runs hypridle. The numbers are saved in ~/.config/snow/power.json
#   power.sh get                  -> screenoff|lock|sleep   (minutes, 0 = Never)
#   power.sh set <screenoff|lock|sleep> <minutes>
#   power.sh start                (Hyprland autostart: write the config and start hypridle)
#   power.sh restart              (write the config and start hypridle again)
#   power.sh sleep | lock | screen-off | screen-on     (used by hypridle and by the Quick Settings button)
D="$HOME/.config/snow"; F="$D/power.json"; H="$HOME/.config/hypr/hypridle.conf"
me="$D/bin/power.sh"
[ -f "$F" ] || echo '{"screenoff":0,"lock":0,"sleep":0}' > "$F"
num() { local v; v=$(jq -r ".$1 // 0" "$F" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] || v=0; echo "$v"; }

gen() {
  local so lk sl; so=$(num screenoff); lk=$(num lock); sl=$(num sleep)
  mkdir -p "$(dirname "$H")"
  {
    echo "# made by snow power.sh - do not edit (change it in Quick Settings > Power Setting)"
    echo "general {"
    echo "    lock_cmd = bash $me lock-now"
    [ "$lk" -gt 0 ] && echo "    before_sleep_cmd = loginctl lock-session"
    echo "    after_sleep_cmd = bash $me screen-on"
    echo "}"
    if [ "$lk" -gt 0 ]; then
      printf '\nlistener {\n    timeout = %d\n    on-timeout = loginctl lock-session\n}\n' $((lk * 60))
    fi
    if [ "$so" -gt 0 ]; then
      printf '\nlistener {\n    timeout = %d\n    on-timeout = bash %s screen-off\n    on-resume = bash %s screen-on\n}\n' $((so * 60)) "$me" "$me"
    fi
    if [ "$sl" -gt 0 ]; then
      printf '\nlistener {\n    timeout = %d\n    on-timeout = systemctl suspend\n}\n' $((sl * 60))
    fi
  } > "$H.tmp" && mv "$H.tmp" "$H"
}
run() {
  command -v hypridle >/dev/null || { echo "hypridle is not installed:  sudo pacman -S hypridle"; return 1; }
  pkill -x hypridle 2>/dev/null; sleep 0.3
  setsid hypridle </dev/null >/dev/null 2>&1 &
}

case "${1:-get}" in
  get)   echo "$(num screenoff)|$(num lock)|$(num sleep)" ;;
  set)
    case "${2:-}" in screenoff|lock|sleep) ;; *) echo "use: power.sh set <screenoff|lock|sleep> <minutes>"; exit 1 ;; esac
    m="${3:-}"; [[ "$m" =~ ^[0-9]+$ ]] && [ "$m" -le 600 ] || { echo "minutes must be 0 to 600"; exit 1; }
    jq --arg k "$2" --argjson m "$m" '.[$k] = $m' "$F" > "$F.tmp" && mv "$F.tmp" "$F" || exit 1
    gen; run ;;
  start|restart) gen; run ;;
  lock-now)      # used by hypridle and by "lock"
    command -v hyprlock >/dev/null || { echo "hyprlock is not installed:  sudo pacman -S hyprlock"; exit 1; }
    bash "$D/bin/apply-lock.sh" >/dev/null 2>&1
    pidof hyprlock >/dev/null || hyprlock ;;
  lock)          loginctl lock-session ;;
  sleep)         systemctl suspend ;;
  screen-off)    hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null 2>&1 ;;
  screen-on)     hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'  >/dev/null 2>&1 ;;
  *) echo "use: power.sh get | set <screenoff|lock|sleep> <minutes> | start | restart | sleep | lock | screen-off | screen-on"; exit 1 ;;
esac
