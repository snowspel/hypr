#!/bin/bash
# no sleep / lock while this runs
if [ -z "${SNOW_INHIBIT:-}" ] && command -v systemd-inhibit >/dev/null; then
  SNOW_INHIBIT=1 exec systemd-inhibit --what=idle:sleep --who=snow --why="update/backup running" bash "$0" "$@"
fi
# System backup (snapshot) with Timeshift. Runs in a terminal (asks for the sudo password).
#   backup.sh            make a backup, waits for Enter at the end
#   backup.sh --quiet    (used by update.sh) does not wait for Enter; exits 1 on failure
quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1
end() { [ "$quiet" = 1 ] || { echo; read -rp "Press Enter to close..." _; }; }

if ! command -v timeshift >/dev/null; then
  echo "timeshift is not installed. Run:  sudo pacman -S timeshift"; end; exit 1
fi
dev=$(findmnt -no SOURCE / | sed 's/\[.*//')
fs=$(findmnt -no FSTYPE /)
mode=--rsync
if [ "$fs" = btrfs ] && sudo btrfs subvolume list / 2>/dev/null | grep -q ' path @$'; then mode=--btrfs; fi

echo "== Backup ($fs, $mode) =="
if sudo timeshift --create $mode --snapshot-device "$dev" --comments "snow backup $(date '+%F %H:%M')" --tags O --scripted; then
  echo
  echo "Backup done. Only the last 5 backups are kept."
  old=$(sudo timeshift --list $mode --snapshot-device "$dev" 2>/dev/null \
        | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}' | sort -u | head -n -5)
  for s in $old; do sudo timeshift --delete --snapshot "$s" $mode --snapshot-device "$dev" --scripted >/dev/null 2>&1 && echo "removed old backup: $s"; done
  end; exit 0
else
  echo; echo "BACKUP FAILED. Read the error above."; end; exit 1
fi
