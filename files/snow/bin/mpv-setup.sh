#!/bin/bash
# mpv setup for snow: puts our mpv config in place (keys, settings, the "Add videos" button, uosc settings)
# and downloads the uosc interface (official GitHub release).
#   mpv-setup.sh            install / update: copies our files (old ones are saved in ~/.config/mpv-backup-<time>)
#   mpv-setup.sh --keep     only fills what is missing, never overwrites (used by tools/restore.sh)
#   mpv-setup.sh --update   same as the first one, and downloads uosc again
# Our files live in ~/.config/snow/mpv  (installed from Snow-Dot/files/snow/mpv). Safe to run again.
S="$HOME/.config/snow/mpv"
M="$HOME/.config/mpv"
mode="${1:-}"
[ -d "$S" ] || { echo "mpv-setup: $S not found (run install.sh first)"; exit 1; }
FILES="input.conf mpv.conf scripts/snow-add.lua script-opts/uosc.conf"
mkdir -p "$M/scripts" "$M/script-opts"

# 1. backup of the files that would be replaced
if [ "$mode" != "--keep" ]; then
  B="$HOME/.config/mpv-backup-$(date +%Y%m%d-%H%M%S)"
  for f in $FILES; do
    [ -f "$M/$f" ] && ! cmp -s "$M/$f" "$S/$f" && { mkdir -p "$B/$(dirname "$f")"; cp -a "$M/$f" "$B/$f"; }
  done
  [ -d "$B" ] && echo "old mpv files saved in $B"
fi

# 2. uosc interface (the download brings its own default uosc.conf, so our files are copied afterwards)
fresh=0
if [ ! -f "$M/scripts/uosc/main.lua" ] || [ "$mode" = "--update" ]; then
  if command -v curl >/dev/null && command -v unzip >/dev/null; then
    T="$(mktemp -d)"
    if curl -fsSL --retry 2 -o "$T/uosc.zip" https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip </dev/null && unzip -qo "$T/uosc.zip" -d "$M"; then
      echo "uosc installed"; fresh=1
    else
      echo "WARN: uosc download failed (internet?). mpv still works with its normal controls. Run again later: bash ~/.config/snow/bin/mpv-setup.sh"
    fi
    rm -rf "$T"
  else
    echo "WARN: curl and unzip are needed to download uosc."
  fi
else
  echo "uosc already installed (use --update to refresh)"
fi

# 3. our files
for f in $FILES; do
  [ -f "$S/$f" ] || continue
  if [ "$mode" = "--keep" ] && [ -f "$M/$f" ] && ! { [ "$f" = "script-opts/uosc.conf" ] && [ "$fresh" = 1 ]; }; then continue; fi
  mkdir -p "$M/$(dirname "$f")"
  cp -f "$S/$f" "$M/$f"
done
echo "mpv config in place (~/.config/mpv)"
