#!/bin/bash
# =============================================================================
#  tools/backup.sh - ONE file (.tar.gz) with all your snow settings.
#                    It is tools/snapshot.sh in --backup mode: the file has the same Snow-Dot shape
#                    (install.sh + files/ + docs/ + tools/), but your Snow-Dot folder is NOT changed.
#
#  use:      bash tools/backup.sh                 -> backups/backup/Snow-Backup-<date>.tar.gz
#            bash tools/backup.sh /path/name.tar.gz
#  restore:  bash tools/restore.sh <that file>    (settings only, or a full install)
#
#  Inside:  Hyprland config + wallpaper, Quickshell panels, snow themes / looks / state / icon font,
#           kitty, mpv, GTK / Qt colors, default apps, app settings (dconf), login screen theme, package lists.
#  NOT inside:  browser profiles (use Brave Sync), your documents / pictures.
#  The newest file is also copied to tools/latest/latest.tar.gz (one file, replaced every time).
# =============================================================================
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/snapshot.sh" --backup "$@"
