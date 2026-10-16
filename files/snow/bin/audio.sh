#!/bin/bash
# Sound output chooser (speaker / headphones / HDMI / Bluetooth).
#   audio.sh list                 -> one line per output:  sink|port|label|active(1/0)|kind
#   audio.sh set <sink> [port]    -> make it the default output and move playing sounds to it
command -v pactl >/dev/null || exit 1
case "${1:-list}" in
  list)
    def=$(pactl get-default-sink 2>/dev/null)
    pactl -f json list sinks 2>/dev/null | jq -r --arg def "$def" '
      .[] | . as $s
      | ((($s.ports // []) | map(select(.availability != "not available"))) ) as $ps
      | (if ($s.name | test("^bluez")) then "bluetooth" else "other" end) as $bt
      | if ($ps | length) > 0 then
          $ps[] | [ $s.name, .name,
                    ($s.description + " - " + .description),
                    (if $s.name == $def and .name == $s.active_port then 1 else 0 end),
                    (if $bt == "bluetooth" then "bluetooth"
                     elif (.name | test("(?i)head(phone|set)")) then "headphones"
                     elif (.name | test("(?i)hdmi|displayport")) then "display"
                     else "speaker" end) ] | join("|")
        else
          [ $s.name, "", $s.description,
            (if $s.name == $def then 1 else 0 end),
            (if $bt == "bluetooth" then "bluetooth" elif ($s.name | test("(?i)hdmi")) then "display" else "speaker" end) ] | join("|")
        end' ;;
  set)
    sink="$2"; port="${3:-}"
    [ -n "$sink" ] || exit 1
    pactl set-default-sink "$sink"
    [ -n "$port" ] && pactl set-sink-port "$sink" "$port"
    for i in $(pactl list short sink-inputs | cut -f1); do pactl move-sink-input "$i" "$sink"; done ;;
esac
