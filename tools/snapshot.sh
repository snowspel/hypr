#!/bin/bash
# =============================================================================
#  tools/snapshot.sh - copies the LIVE system files into the Snow-Dot folder shape
#                      (install.sh + files/ + docs/ + tools/) and makes ONE .tar.gz of it.
#                      tools/backup.sh is the same engine in --backup mode.
#
#    bash tools/snapshot.sh             UPDATES files/ of this Snow-Dot folder, rebuilds docs/snow-hyprland.txt,
#                                       and writes backups/snapshot/Snow-Snapshot-<date>.tar.gz
#                                       (nothing is pushed anywhere; GitHub is handled by hand)
#    bash tools/snapshot.sh --backup    (= bash tools/backup.sh) does NOT touch files/.
#                                       It only writes backups/backup/Snow-Backup-<date>.tar.gz
#                                       (optional argument: another file name)
#
#  Every run also copies the new file to tools/latest/latest.tar.gz (the old copy is replaced),
#  so tools/latest/ always holds exactly ONE file. Both kinds of file look the same inside and
#  both can be restored with tools/restore.sh (settings only, or a full install).
#  Run it as a normal user; no sudo is needed.
#  In normal (snapshot) mode the old files/ is first saved as backups/history/files-before-<date>.tar.gz.
#  Nothing in backups/ is ever deleted automatically; delete old files by hand when you want.
# =============================================================================

T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this tools/ folder
D="$(dirname "$T")"                                # the Snow-Dot folder (parent of tools/)
BK="$D/backups"
ts=$(date +%F_%H-%M)
MODE=snapshot; out=""
for a in "$@"; do
  case "$a" in --backup) MODE=backup ;; *) out="$a" ;; esac
done
if [ "$MODE" = backup ]; then
  # work in a temporary copy: the real folder stays untouched
  STAGE=$(mktemp -d) || exit 1
  trap 'rm -rf "$STAGE"' EXIT
  ROOT="$STAGE/Snow-Dot"; mkdir -p "$ROOT"
  tar -C "$D" --exclude=./backups --exclude=./tools/latest --exclude=./.git -cf - . | tar -C "$ROOT" -xf -
  out="${out:-$BK/backup/Snow-Backup-$ts.tar.gz}"
else
  ROOT="$D"
  out="${out:-$BK/snapshot/Snow-Snapshot-$ts.tar.gz}"
fi
F="$ROOT/files"
mkdir -p "$F" "$F/extras"

if [ "$MODE" = snapshot ]; then
  mkdir -p "$BK/history"
  echo "== backup of the old files/ into backups/history =="
  tar -czf "$BK/history/files-before-$ts.tar.gz" -C "$D" files 2>/dev/null && echo "backups/history/files-before-$ts.tar.gz"
fi

clean_baks() { find "$1" \( -name '*.bak*' -o -name '*.before-snow-*' -o -name '*~' \) -exec rm -rf {} + 2>/dev/null; }

copy_dir() {  # copy_dir <src> <dst>
  if [ -d "$1" ]; then
    rm -rf "$2"; mkdir -p "$2"; cp -r "$1"/. "$2"/; clean_baks "$2"
    echo "OK    $1"
  else
    echo "SKIP  $1 (not found)"
  fi
}
copy_file() {  # copy_file <src> <dst>
  if [ -f "$1" ]; then mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "OK    $1"
  else echo "SKIP  $1 (not found)"; fi
}

echo; echo "== Quickshell / snow / hypr =="
copy_dir  "$HOME/.config/quickshell/snow" "$F/quickshell"
copy_dir  "$HOME/.config/snow"            "$F/snow"
copy_file "$HOME/.config/hypr/hyprland.lua"    "$F/hypr/hyprland.lua"
copy_file "$HOME/.config/hypr/theme-colors.lua" "$F/hypr/theme-colors.lua"
copy_file "$HOME/.config/hypr/look.lua"        "$F/hypr/look.lua"
for f in "$HOME"/.config/hypr/*.lua; do   # any other lua file you added next to hyprland.lua
  [ -f "$f" ] || continue
  case "$(basename "$f")" in hyprland.lua|theme-colors.lua|look.lua) ;; *) copy_file "$f" "$F/hypr/$(basename "$f")" ;; esac
done

# mpv: the live files in ~/.config/mpv are the newest, so they go into files/snow/mpv (the source that install.sh uses)
for p in mpv.conf input.conf scripts/snow-add.lua script-opts/uosc.conf; do
  [ -f "$HOME/.config/mpv/$p" ] && copy_file "$HOME/.config/mpv/$p" "$F/snow/mpv/$p"
done

mkdir -p "$F/systemd/user"
for u in snow-update-check.service snow-update-check.timer; do copy_file "$HOME/.config/systemd/user/$u" "$F/systemd/user/$u"; done

echo; echo "== Wallpaper (images) =="
mkdir -p "$F/wallpaper"
shopt -s nullglob nocaseglob
imgs=("$HOME"/.config/hypr/wallpaper/*.{jpg,jpeg,png,webp})
shopt -u nullglob nocaseglob
if [ ${#imgs[@]} -gt 0 ]; then
  rm -f "$F"/wallpaper/*; cp "${imgs[@]}" "$F/wallpaper/"; echo "OK    ${#imgs[@]} image(s)"
else echo "SKIP  no wallpaper images found"; fi

echo; echo "== SDDM theme =="
copy_dir "/usr/share/sddm/themes/snow" "$F/sddm/snow"
rm -f "$F"/sddm/snow/background.jpg "$F"/sddm/snow/background-src.jpg   # the service makes it again

echo; echo "== system/ (login wallpaper service; HOME -> __HOME__) =="
mkdir -p "$F/system"
[ -f /usr/local/bin/snow-sddm-wallpaper ] && sed "s|$HOME|__HOME__|g" /usr/local/bin/snow-sddm-wallpaper > "$F/system/snow-sddm-wallpaper" && echo "OK    snow-sddm-wallpaper"
[ -f /etc/systemd/system/snow-sddm-wallpaper.path ] && sed "s|$HOME|__HOME__|g" /etc/systemd/system/snow-sddm-wallpaper.path > "$F/system/snow-sddm-wallpaper.path" && echo "OK    .path"
copy_file /etc/systemd/system/snow-sddm-wallpaper.service "$F/system/snow-sddm-wallpaper.service"

echo; echo "== personal settings (GTK / Qt colors, default apps, mpv, kitty, app settings) =="
H="$F/extras/home"; rm -rf "$H"; mkdir -p "$H"
( cd "$HOME" && for p in .config/gtk-3.0 .config/gtk-4.0 .config/kdeglobals .config/mimeapps.list .local/share/color-schemes/Snow.colors \
      .config/kitty/kitty.conf .config/mpv/mpv.conf .config/mpv/input.conf \
      .config/mpv/scripts/snow-add.lua .config/mpv/script-opts/uosc.conf .config/mpv/scripts/uosc .config/mpv/fonts \
      .config/kitty/snow-keys.conf .bashrc .gitconfig .config/user-dirs.dirs .config/user-dirs.locale \
      .config/gwenviewrc .config/swappy .local/share/applications; do
    [ -e "$p" ] && cp -a --parents "$p" "$H/" && echo "OK    ~/$p"
  done )
clean_baks "$H"
if command -v dconf >/dev/null; then dconf dump / > "$F/extras/dconf.ini" 2>/dev/null && echo "OK    dconf (Nautilus, Mousepad ... settings)"; fi

echo; echo "== extras (reference) =="
copy_file "$HOME/.config/kitty/kitty.conf" "$F/extras/kitty.conf"
for c in /etc/sddm.conf.d/*.conf; do copy_file "$c" "$F/extras/sddm.conf.d/$(basename "$c")"; done
{
  echo "# snapshot $ts"
  echo "kernel:      $(uname -r)"
  echo "hyprland:    $(hyprctl version 2>/dev/null | head -1)"
  echo "quickshell:  $(pacman -Q quickshell 2>/dev/null)"
  echo "sddm:        $(pacman -Q sddm 2>/dev/null)"
  echo "installed kernels: $(pacman -Qq | grep -E '^linux(-lts|-zen|-hardened|-rt)?(-headers)?$' | tr '\n' ' ')"
  echo "--- dkms status";   dkms status 2>/dev/null
  echo "--- GPU";           lspci -nn 2>/dev/null | grep -Ei 'vga|3d'
  echo "--- sddm conf.d";   ls /etc/sddm.conf.d 2>/dev/null
} > "$F/extras/system-info.txt"
pacman -Qqen > "$F/extras/pkglist-official.txt"
pacman -Qqem > "$F/extras/pkglist-aur.txt"
echo "OK    package lists (official: $(wc -l < "$F/extras/pkglist-official.txt"), aur: $(wc -l < "$F/extras/pkglist-aur.txt"))"

if [ "$MODE" = snapshot ]; then
  echo; echo "== rebuilding docs/snow-hyprland.txt =="
  bash "$D/docs/make-doc.sh" && echo "OK    $D/docs/snow-hyprland.txt"

  echo; echo "== doctor =="
  [ -f "$T/doctor.sh" ] && bash "$T/doctor.sh" | tail -n 25
fi

mkdir -p "$(dirname "$out")"
tar -czf "$out" -C "$(dirname "$ROOT")" --exclude="$(basename "$ROOT")/backups" --exclude="$(basename "$ROOT")/tools/latest" "$(basename "$ROOT")" || { echo "could not write $out"; rm -f "$out"; exit 1; }
tar -tzf "$out" >/dev/null 2>&1 || { echo "the file is damaged"; exit 1; }
echo
echo "Ready: $out  ($(du -h "$out" | cut -f1))"
echo "Restore with:  bash $T/restore.sh \"$out\"     (settings only, or full install)"
echo "IMPORTANT: before you format, copy this .tar.gz to a USB drive or another disk."

# keep ONE copy of the newest file in tools/latest/latest.tar.gz (it replaces the old one).
# "bash tools/restore.sh" without a file name restores from it. Only a file that really has snow settings is kept.
if tar -tzf "$out" 2>/dev/null | grep -Eq '(^|/)files/snow/themes/'; then
  LB="$T/latest"; mkdir -p "$LB"
  if cp -f "$out" "$LB/latest.tar.gz.tmp" && mv -f "$LB/latest.tar.gz.tmp" "$LB/latest.tar.gz"; then
    printf '%s\n' "$(basename "$out")" > "$LB/from.txt"
    echo "Also copied to:  $LB/latest.tar.gz   (replaces the previous one; restore with:  bash tools/restore.sh)"
  fi
fi
