#!/bin/bash
# Polkit authentication agent.
# Normally Quickshell itself is the agent (components/PolkitDialog.qml), so nothing is started here.
# Only if this Quickshell build has no Polkit module, hyprpolkitagent is started as a fallback.
for d in /usr/lib/qt6/qml/Quickshell/Services/Polkit /usr/lib/qml/Quickshell/Services/Polkit /usr/lib/x86_64-linux-gnu/qt6/qml/Quickshell/Services/Polkit; do
  [ -d "$d" ] && exit 0
done
pgrep -x hyprpolkitagent >/dev/null && exit 0
for b in /usr/lib/hyprpolkitagent/hyprpolkitagent /usr/bin/hyprpolkitagent; do
  if [ -f "$b" ] && [ -x "$b" ]; then exec "$b"; fi
done
exec systemctl --user start hyprpolkitagent.service
