#!/bin/bash
# Change the wallpaper.
#   wallpaper.sh pick          open a file chooser window, then use the chosen picture
#   wallpaper.sh set <file>    use this picture (jpg, jpeg, png, webp)
# The chosen picture is COPIED to ~/.config/hypr/wallpaper/wallpaper.<ext> and replaces the old wallpaper there.
# The old wallpaper is kept one time in ~/.config/hypr/wallpaper/previous/ (your chosen file itself is never touched).
D="$HOME/.config/snow"
W="$HOME/.config/hypr/wallpaper"
QS=(qs -p "$HOME/.config/quickshell/snow")

setwall() {
  local f="$1" ext tmp old
  [ -f "$f" ] || { echo "file not found: $f"; return 1; }
  ext="${f##*.}"; ext="${ext,,}"
  case "$ext" in jpg|jpeg|png|webp) ;; *) echo "not a supported picture: $f"; return 1 ;; esac
  mkdir -p "$W/previous"
  tmp=$(mktemp "$W/.new.XXXXXX") || return 1
  if ! cp "$f" "$tmp"; then rm -f "$tmp"; return 1; fi
  if command -v identify >/dev/null && ! identify -quiet "$tmp[0]" >/dev/null 2>&1; then
    rm -f "$tmp"; echo "this file is not a valid picture"; return 1
  fi
  # old wallpaper(s) -> previous/ (the older "previous" is removed)
  shopt -s nullglob nocaseglob
  old=("$W"/*.{jpg,jpeg,png,webp})
  rm -f "$W"/previous/*
  [ ${#old[@]} -gt 0 ] && mv -f "${old[@]}" "$W/previous/"
  shopt -u nullglob nocaseglob
  mv -f "$tmp" "$W/wallpaper.$ext"
  touch "$W/wallpaper.$ext"
  # wallpaper colors ON: take the new colors
  if [ "$(cat "$D/autowall" 2>/dev/null)" = on ]; then
    bash "$D/bin/switch-theme.sh" auto on >/dev/null 2>&1
  fi
  echo "wallpaper: $W/wallpaper.$ext"
}

case "${1:-}" in
  set) setwall "${2:-}" ;;
  pick)
    if ! command -v zenity >/dev/null; then
      echo "zenity is not installed:  sudo pacman -S zenity"; sleep 4
    else
      start="$HOME/Pictures/"; [ -d "$start" ] || start="$HOME/"
      f=$(zenity --file-selection --title="Choose wallpaper" --filename="$start" \
            --file-filter='Pictures | *.jpg *.jpeg *.png *.webp *.JPG *.JPEG *.PNG *.WEBP' 2>/dev/null)
      [ -n "$f" ] && setwall "$f"
    fi
    "${QS[@]}" ipc call themes toggle >/dev/null 2>&1 ;;   # show the Themes menu again
  *) echo "use: wallpaper.sh pick | set <file>"; exit 1 ;;
esac
