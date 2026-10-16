#!/bin/bash
# Default applications: web browser, PDF, archives, video/audio, plain text.
# Each app is set only if its .desktop file exists. Safe to run again.
#   To use LibreWolf as the default browser:  xdg-settings set default-web-browser librewolf.desktop
dirs="/usr/share/applications $HOME/.local/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"
find_desktop() {   # find_desktop <file.desktop> ...  -> prints the first one that exists
  for n in "$@"; do for d in $dirs; do [ -f "$d/$n" ] && { echo "$n"; return 0; }; done; done
  return 1
}
setmime() {        # setmime <desktop file> <mime types...>
  local app; app=$(find_desktop "$1") || { echo "skip: $1 not installed"; return; }
  shift
  for m in "$@"; do xdg-mime default "$app" "$m"; done
  echo "default set: $app"
}

# Browser: Brave Origin (first brave*.desktop that exists)
brave=$(ls /usr/share/applications 2>/dev/null | grep -i '^brave.*\.desktop$' | head -n 1)
if [ -n "$brave" ]; then
  xdg-settings set default-web-browser "$brave" 2>/dev/null && echo "default browser: $brave"
else
  echo "skip: no Brave desktop file found"
fi

setmime org.gnome.Papers.desktop application/pdf
setmime org.gnome.FileRoller.desktop application/zip application/x-7z-compressed application/vnd.rar application/x-rar \
  application/x-tar application/gzip application/x-xz application/x-bzip2 application/x-compressed-tar application/zstd
setmime mpv.desktop video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg \
  audio/mpeg audio/flac audio/x-wav audio/ogg audio/mp4
setmime org.xfce.mousepad.desktop text/plain
setmime org.kde.gwenview.desktop image/jpeg image/png image/webp image/gif image/bmp image/tiff image/avif image/heic image/heif image/jxl
