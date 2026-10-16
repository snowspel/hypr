#!/bin/bash
# Mouse wakes the PC from sleep.
# Why it does not by default: Linux often keeps "wake from sleep" switched OFF for USB mice (keyboards usually have it ON).
# This finds your USB mouse / mouse receiver by itself, switches wake ON now, and saves a udev rule so it stays ON after every boot.
#   bash mouse-wake.sh          do it (asks for the sudo password)
#   bash mouse-wake.sh --check  only show what it finds, change nothing
# Bluetooth mice are different (the Bluetooth chip has to wake the PC); this script says so if it finds one.
SYS="${SNOW_USB_SYSFS:-/sys/bus/usb/devices}"
RULE="${SNOW_UDEV_RULE:-/etc/udev/rules.d/90-snow-mouse-wake.rules}"
check=0; [ "${1:-}" = "--check" ] && check=1

found=()   # "vendor:product|sysfs-dir|name"
for d in "$SYS"/*; do
  [ -f "$d/idVendor" ] || continue
  case "$(basename "$d")" in *:*) continue ;; esac
  ismouse=0
  for i in "$d":*; do
    [ -f "$i/bInterfaceClass" ] || continue
    [ "$(cat "$i/bInterfaceClass" 2>/dev/null)" = 03 ] && [ "$(cat "$i/bInterfaceProtocol" 2>/dev/null)" = 02 ] && ismouse=1
  done
  [ "$ismouse" = 1 ] || continue
  v=$(cat "$d/idVendor"); p=$(cat "$d/idProduct")
  n=$(cat "$d/product" 2>/dev/null); [ -n "$n" ] || n="USB mouse"
  found+=("$v:$p|$d|$n")
done

if [ ${#found[@]} -eq 0 ]; then
  echo "No USB mouse found."
  if command -v bluetoothctl >/dev/null && bluetoothctl devices Connected 2>/dev/null | grep -qi .; then
    echo "You use a Bluetooth device. Bluetooth wake needs the Bluetooth chip to wake the PC: this script cannot do that."
  fi
  exit 0
fi

rules=""
for f in "${found[@]}"; do
  id="${f%%|*}"; rest="${f#*|}"; dir="${rest%%|*}"; name="${rest#*|}"
  w="$dir/power/wakeup"
  if [ -f "$w" ]; then st=$(cat "$w"); else st="(no wake switch)"; fi
  echo "found: $name  [$id]   wake now: $st"
  [ -f "$w" ] || continue
  rules+="ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"${id%%:*}\", ATTR{idProduct}==\"${id##*:}\", ATTR{power/wakeup}=\"enabled\"
"
  if [ "$check" = 0 ] && [ "$st" != enabled ]; then
    echo enabled | sudo tee "$w" >/dev/null && echo "  -> wake switched ON now"
  fi
done

if [ "$check" = 0 ] && [ -n "$rules" ]; then
  printf '# snow: let the USB mouse wake the PC from sleep\n%s' "$rules" | sudo tee "$RULE" >/dev/null && echo "saved: $RULE (stays after reboot)"
  sudo udevadm control --reload 2>/dev/null
  echo "Test: use Sleep now, then move or click the mouse."
fi
