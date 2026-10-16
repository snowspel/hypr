#!/bin/bash
# no sleep / lock while this runs
if [ -z "${SNOW_INHIBIT:-}" ] && command -v systemd-inhibit >/dev/null; then
  SNOW_INHIBIT=1 exec systemd-inhibit --what=idle:sleep --who=snow --why="update/backup running" bash "$0" "$@"
fi
# Update: backup first, then pacman + AUR (+ flatpak apps, if you have any). Runs in a terminal.
D="$HOME/.config/snow"
echo "== 1/4  Backup (before the update) =="
if ! bash "$D/bin/backup.sh" --quiet; then
  read -rp "Backup failed. Update anyway? [y/N] " a
  [ "$a" = y ] || [ "$a" = Y ] || { echo "Update cancelled."; read -rp "Enter..." _; exit 1; }
fi
echo; echo "== 2/4  Official packages (pacman -Syu) =="
sudo pacman -Syu
echo; echo "== 3/4  AUR packages (yay) =="
command -v yay >/dev/null && yay -Sua || echo "yay not found, skipping"
if command -v flatpak >/dev/null; then echo; echo "== 4/4  Flatpak =="; sudo flatpak update -y; fi
mkdir -p "$HOME/.cache/snow"; echo 0 > "$HOME/.cache/snow/updates"
echo
echo "If the kernel or NVIDIA was updated, please reboot."
echo "Update finished. If something looks wrong, restore a snapshot from your Timeshift app."
read -rp "Press Enter to close..." _
