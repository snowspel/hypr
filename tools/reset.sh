#!/bin/bash
# =============================================================================
#  tools/reset.sh - back to a FRESH, plain Hyprland (like a new install).
#
#  1. makes a backup file of all your settings first (tools/backup.sh)
#     -> backups/backup/Snow-Backup-before-reset-<date>.tar.gz
#  2. removes the snow config: Hyprland config, Quickshell panels, snow themes,
#     kitty / GTK / Qt colors, mpv config
#  3. (optional) puts the login screen back to the SDDM default
#  4. logs you out. Hyprland then makes its own default config at the next start.
#
#  Your programs (Brave, kitty ...) and your files stay. Nothing is uninstalled.
#  The Snow-Dot folder is not touched either.
#  To come back to snow:   bash tools/restore.sh          (uses tools/latest/latest.tar.gz)
#                          or  bash tools/restore.sh <the backup file>
#                          or  bash install.sh            (from the Snow-Dot folder)
# =============================================================================
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this tools/ folder
D="$(dirname "$T")"                                # the Snow-Dot folder (parent of tools/)
if [ ! -d "$HOME/.config/snow/themes" ]; then
  echo
  echo "No snow settings found. It looks like the reset was already done. Nothing to do."
  echo "Your backups (OK = has snow settings):"
  for b in "$T"/latest/*.tar.gz "$D"/backups/backup/*.tar.gz "$D"/backups/snapshot/*.tar.gz; do
    [ -f "$b" ] || continue
    if tar -tzf "$b" 2>/dev/null | grep -Eq 'files/snow/themes/'; then echo "  OK     $b"; else echo "  EMPTY  $b"; fi
  done
  echo "To get snow back:  bash $T/restore.sh        (no name = the last backup, tools/latest/latest.tar.gz)"
  exit 0
fi
cat << 'EOT'

  This will return Hyprland to its DEFAULT settings.
  A backup file is made first, so you can come back.

EOT
read -rp "  Type RESET to continue: " a
[ "$a" = RESET ] || { echo "cancelled. nothing was changed."; exit 0; }

ts=$(date +%F_%H-%M)
out="$D/backups/backup/Snow-Backup-before-reset-$ts.tar.gz"
echo; echo "== 1. backup =="
bash "$T/backup.sh" "$out" || { echo "Backup failed. Nothing was changed."; exit 1; }
if [ -f "$HOME/.config/hypr/hyprland.lua" ] && ! tar -tzf "$out" | grep -Eq 'files/hypr/hyprland\.lua'; then
  echo "The backup does not contain hyprland.lua. Nothing was changed."; exit 1
fi

echo; echo "== 2. removing the snow settings =="
pkill -x qs 2>/dev/null
pkill -x hypridle 2>/dev/null
if command -v systemctl >/dev/null; then
  systemctl --user disable --now snow-update-check.timer 2>/dev/null
  rm -f "$HOME/.config/systemd/user/snow-update-check.service" "$HOME/.config/systemd/user/snow-update-check.timer"
  systemctl --user daemon-reload 2>/dev/null
fi
rm -rf "$HOME/.config/hypr" "$HOME/.config/quickshell/snow" "$HOME/.config/snow" "$HOME/.cache/snow" "$HOME/.local/share/fonts/snow" "$HOME/.config/mpv/mpv.conf" "$HOME/.config/mpv/input.conf" "$HOME/.config/mpv/scripts/snow-add.lua" "$HOME/.config/mpv/scripts/uosc" "$HOME/.config/mpv/script-opts/uosc.conf" "$HOME/.config/mpv/fonts/uosc_icons.otf" "$HOME/.config/mpv/fonts/uosc_textures.ttf"
rm -f "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/settings.ini" \
      "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/settings.ini" \
      "$HOME/.config/kdeglobals" "$HOME/.local/share/color-schemes/Snow.colors" \
      "$HOME/.config/kitty/snow-theme.conf" "$HOME/.config/kitty/snow-keys.conf"
if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
  sed -i -e '/^include snow-theme\.conf$/d' -e '/^include snow-keys\.conf$/d' -e '/^font_family      JetBrains Mono$/d' -e '/^font_size        11\.0$/d' "$HOME/.config/kitty/kitty.conf"
fi
[ -f "$HOME/.bashrc" ] && sed -i -e "/^alias snow=/d" -e "/snow\/prompt\.sh/d" "$HOME/.bashrc"
if command -v gsettings >/dev/null; then
  for k in icon-theme color-scheme gtk-theme; do gsettings reset org.gnome.desktop.interface "$k" 2>/dev/null; done
fi
echo "done."

echo; echo "== 3. login screen =="
read -rp "Also put the login screen back to the SDDM default? (needs sudo) [y/N] " b
if [ "${b,,}" = y ]; then
  sudo systemctl disable --now snow-sddm-wallpaper.path 2>/dev/null
  sudo rm -f /etc/sddm.conf.d/zz-snow.conf /etc/systemd/system/snow-sddm-wallpaper.path /etc/systemd/system/snow-sddm-wallpaper.service /usr/local/bin/snow-sddm-wallpaper
  sudo rm -rf /usr/share/sddm/themes/snow
  sudo systemctl daemon-reload
  echo "login screen reset."
else
  echo "login screen kept."
fi

echo
echo "================================================================"
echo " Backup file:  $out"
echo " To go back to snow:   bash $T/restore.sh \"$out\""
echo " If the screen is empty after login:  press Ctrl+Alt+F3, log in, run the line above."
echo "================================================================"
read -rp "Log out now, so Hyprland starts with its default settings? [Y/n] " c
if [ "${c,,}" != n ]; then
  if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then hyprctl dispatch exit
  else echo "Please log out now."; fi
fi
