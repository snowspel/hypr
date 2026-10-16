#!/bin/bash
# =============================================================================
#  tools/restore.sh - put snow back. It accepts:
#     * a backup / snapshot FILE   (.tar.gz made by tools/backup.sh or tools/snapshot.sh)
#     * a Snow-Dot FOLDER          (for example ~/Snow-Dot)
#  use:  bash tools/restore.sh                    the LAST backup (tools/latest/latest.tar.gz)
#        bash tools/restore.sh <file.tar.gz>      one chosen file (for example from backups/backup/)
#        bash tools/restore.sh ~/Snow-Dot         the Snow-Dot folder
#        bash tools/restore.sh --list             shows what it can find
#  For a Snow-Dot folder / file it asks:  1) settings only (fast)   2) full install (programs too)
#  Works from a text console too (Ctrl+Alt+F3), if the desktop does not start.
# =============================================================================
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this tools/ folder
D="$(dirname "$T")"                                # the Snow-Dot folder (parent of tools/)

# ask <var> <prompt>: reads the answer from the keyboard itself (/dev/tty), after throwing away stray key presses
ask() {
  local _a=""
  if { : </dev/tty; } 2>/dev/null; then
    while IFS= read -r -t 0.05 -n 1 _ </dev/tty 2>/dev/null; do :; done
    read -rp "$2" _a </dev/tty
  else
    read -rp "$2" _a
  fi
  printf -v "$1" '%s' "$_a"
}

# kind <path>:  dot (Snow-Dot shape, has files/snow/themes) | empty | none
kind() {
  local x="$1" l
  if [ -d "$x" ]; then
    [ -d "$x/files/snow/themes" ] && { echo dot; return; }
    [ -f "$x/install.sh" ] && { echo empty; return; }
    echo none; return
  fi
  [ -f "$x" ] || { echo none; return; }
  l=$(tar -tzf "$x" 2>/dev/null) || { echo none; return; }
  echo "$l" | grep -Eq '(^|/)files/snow/themes/' && { echo dot; return; }
  echo "$l" | grep -Eq '(^|/)install\.sh$|home/' && { echo empty; return; }
  echo none
}

list_all() {
  echo "Snow-Dot folder (this one):"
  case "$(kind "$D")" in dot) echo "  OK     $D";; *) echo "  EMPTY  $D   (no files/snow/themes inside)";; esac
  echo "Backup files  (OK = has your snow settings, EMPTY = made after a reset, do not use):"
  local b any=0
  for b in "$T"/latest/*.tar.gz "$D"/backups/backup/*.tar.gz "$D"/backups/snapshot/*.tar.gz; do
    [ -f "$b" ] || continue; any=1
    case "$(kind "$b")" in dot) echo "  OK     $b";; *) echo "  EMPTY  $b";; esac
  done
  [ "$any" = 1 ] || echo "  (none yet - make one:  bash $T/backup.sh)"
}

src="${1:-}"
if [ "$src" = "--list" ] || [ "$src" = "-l" ]; then list_all; exit 0; fi
if [ -z "$src" ]; then
  last="$T/latest/latest.tar.gz"
  if [ -f "$last" ]; then
    src="$last"
    echo "Using the LAST backup:  $last"
    [ -f "$T/latest/from.txt" ] && echo "  (made as: $(cat "$T/latest/from.txt"), file date: $(date -r "$last" '+%Y-%m-%d %H:%M'))"
  else
    echo "There is no last backup yet (tools/latest/latest.tar.gz). Make one:  bash $T/backup.sh"
    echo "or choose a file:  bash $T/restore.sh <backup file  or  Snow-Dot folder>"
    echo; list_all
    exit 1
  fi
elif [ ! -f "$src" ] && [ ! -d "$src" ]; then
  echo "not found: $src"
  echo "use:  bash $T/restore.sh <backup file  or  Snow-Dot folder>   (or no name = the last backup)"
  echo; list_all
  exit 1
fi
k=$(kind "$src")
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
case "$k" in
  none)  echo "this is not a snow backup / snapshot"; exit 1 ;;
  empty) echo "STOP: this has NO snow settings (it was probably made after a reset)."
         echo "Restoring it would not bring your desktop back. Use another one:"; echo; list_all; exit 1 ;;
esac

root=""
if [ "$k" = dot ]; then
  if [ -d "$src" ]; then root="$(cd "$src" && pwd)"
  else
    tar -xzf "$src" -C "$tmp" || { echo "could not read the file"; exit 1; }
    root=$(find "$tmp" -maxdepth 3 -type d -path '*/files/snow' | head -1); root="${root%/files/snow}"
    [ -d "$root/files" ] || { echo "this is not a snow snapshot"; exit 1; }
  fi
  [ -f "$root/files/extras/system-info.txt" ] && { echo "---"; head -n 3 "$root/files/extras/system-info.txt"; echo "---"; }
  echo "What do you want?"
  echo "  1) Settings only   (fast; your programs stay as they are)"
  echo "  2) Full install    (programs + settings; runs install.sh, asks for sudo, takes time)"
  ask ch "Choose 1 or 2 [1]: "
  if [ "$ch" = 2 ]; then
    [ -f "$root/install.sh" ] || { echo "no install.sh in it"; exit 1; }
    bash "$root/install.sh" || echo "install.sh reported problems (see above); continuing with your saved settings."
    echo; echo "Programs are installed. Now your saved settings go on top."
  fi
fi

ask a "Put these settings back now? [y/N] "
[ "${a,,}" = y ] || { echo "cancelled"; exit 0; }

pkill -x qs 2>/dev/null
pkill -x hypridle 2>/dev/null

F="$root/files"
mkdir -p "$HOME/.config/quickshell/snow" "$HOME/.config/snow" "$HOME/.config/hypr/wallpaper" "$HOME/.config/systemd/user"
cp -a "$F/quickshell/." "$HOME/.config/quickshell/snow/"
cp -a "$F/snow/."       "$HOME/.config/snow/"
for f in "$F"/hypr/*.lua; do [ -f "$f" ] && cp -f "$f" "$HOME/.config/hypr/$(basename "$f")"; done
shopt -s nullglob nocaseglob
for w in "$F"/wallpaper/*.{jpg,jpeg,png,webp}; do cp -f "$w" "$HOME/.config/hypr/wallpaper/"; done
shopt -u nullglob nocaseglob
for u in "$F"/systemd/user/snow-update-check.*; do [ -f "$u" ] && cp -f "$u" "$HOME/.config/systemd/user/"; done
[ -d "$F/extras/home" ] && cp -a "$F/extras/home/." "$HOME/"
[ -f "$F/extras/dconf.ini" ] && command -v dconf >/dev/null && dconf load / < "$F/extras/dconf.ini" 2>/dev/null

chmod +x "$HOME"/.config/snow/bin/*.sh 2>/dev/null
# kitty keys file is read by kitty.conf (include snow-keys.conf): make it if the backup did not have it
[ -f "$HOME/.config/kitty/snow-keys.conf" ] || { [ -f "$HOME/.config/snow/kitty-keys.conf" ] && { mkdir -p "$HOME/.config/kitty"; cp "$HOME/.config/snow/kitty-keys.conf" "$HOME/.config/kitty/snow-keys.conf"; }; }
bash "$HOME/.config/snow/bin/mpv-setup.sh" --keep </dev/null    # mpv: fills what the backup did not bring (uosc, config files)
bash "$HOME/.config/snow/bin/install-fonts.sh" >/dev/null 2>&1    # icon font back in place
grep -q "alias snow=" "$HOME/.bashrc" 2>/dev/null || echo "alias snow='qs -p ~/.config/quickshell/snow'" >> "$HOME/.bashrc"
grep -q "snow/prompt.sh" "$HOME/.bashrc" 2>/dev/null || echo '[ -f ~/.config/snow/prompt.sh ] && . ~/.config/snow/prompt.sh' >> "$HOME/.bashrc"
if [ -d "$HOME/.config/systemd/user" ] && command -v systemctl >/dev/null; then
  systemctl --user daemon-reload 2>/dev/null
  systemctl --user enable --now snow-update-check.timer 2>/dev/null
fi
bash "$HOME/.config/snow/bin/switch-theme.sh" --restore </dev/null >/dev/null 2>&1
if command -v qs >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  setsid qs -p "$HOME/.config/quickshell/snow" </dev/null >/dev/null 2>&1 &    # panels back, without a new login
  bash "$HOME/.config/snow/bin/power.sh" start </dev/null >/dev/null 2>&1       # sleep/lock timers back
fi
echo "settings restored."

# ---- login screen (needs sudo)
sddm_dot() {
  local F="$1/files" t
  [ -d "$F/sddm/snow" ] || return 1
  sudo mkdir -p /usr/share/sddm/themes/snow && sudo cp -r "$F/sddm/snow/." /usr/share/sddm/themes/snow/
  [ -f "$F/extras/sddm.conf.d/zz-snow.conf" ] && { sudo mkdir -p /etc/sddm.conf.d; sudo install -m 644 "$F/extras/sddm.conf.d/zz-snow.conf" /etc/sddm.conf.d/zz-snow.conf; }
  t=$(mktemp -d)
  for f in snow-sddm-wallpaper snow-sddm-wallpaper.path; do [ -f "$F/system/$f" ] && sed "s|__HOME__|$HOME|g" "$F/system/$f" > "$t/$f"; done
  [ -f "$t/snow-sddm-wallpaper" ] && sudo install -m 755 "$t/snow-sddm-wallpaper" /usr/local/bin/snow-sddm-wallpaper
  [ -f "$t/snow-sddm-wallpaper.path" ] && sudo install -m 644 "$t/snow-sddm-wallpaper.path" /etc/systemd/system/snow-sddm-wallpaper.path
  [ -f "$F/system/snow-sddm-wallpaper.service" ] && sudo install -m 644 "$F/system/snow-sddm-wallpaper.service" /etc/systemd/system/snow-sddm-wallpaper.service
  rm -rf "$t"
}
has_login=0
[ -d "$root/files/sddm/snow" ] && has_login=1
if [ "$has_login" = 1 ]; then
  ask b "Also restore the login screen (needs sudo)? [y/N] "
  if [ "${b,,}" = y ]; then
    sddm_dot "$root"
    sudo systemctl daemon-reload
    sudo systemctl enable --now snow-sddm-wallpaper.path 2>/dev/null
    sudo systemctl start snow-sddm-wallpaper.service 2>/dev/null
    echo "login screen restored."
  fi
fi
echo
echo "Done. Log out and log in again (or restart Hyprland) to see everything."
echo "If programs are missing, run:  bash $D/install.sh   (or choose 'Full install' above)"
