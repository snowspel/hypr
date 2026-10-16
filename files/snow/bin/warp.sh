#!/bin/bash
# Cloudflare WARP:  warp.sh status  ->  on | off | wait | na      warp.sh toggle
note() { command -v notify-send >/dev/null && notify-send -a snow "WARP" "$1"; }
case "${1:-status}" in
  status)
    command -v warp-cli >/dev/null || { echo na; exit 0; }
    systemctl is-active --quiet warp-svc || { echo na; exit 0; }
    s=$(timeout 3 warp-cli --accept-tos status 2>&1)
    if   echo "$s" | grep -qi 'Status update: Connected';  then echo on
    elif echo "$s" | grep -qi 'Connecting';                then echo wait
    else echo off; fi ;;
  toggle)
    command -v warp-cli >/dev/null || { note "warp-cli is not installed (run: yay -S cloudflare-warp-bin)"; exit 1; }
    systemctl is-active --quiet warp-svc || { note "warp-svc is not running. Run: sudo systemctl enable --now warp-svc"; exit 1; }
    # first time: the device must be registered
    if ! warp-cli --accept-tos registration show >/dev/null 2>&1; then
      warp-cli --accept-tos registration new >/dev/null 2>&1 || warp-cli --accept-tos register >/dev/null 2>&1
    fi
    if warp-cli --accept-tos status 2>&1 | grep -qi 'Status update: Connected'; then
      warp-cli --accept-tos disconnect
    else
      warp-cli --accept-tos connect
    fi ;;
esac
