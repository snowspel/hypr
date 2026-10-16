#!/bin/bash
# =============================================================================
#  tools/doctor.sh  -  system health check (changes nothing, only looks)
#  Run:      bash tools/doctor.sh
#  Every line is PASS / WARN / FAIL. The totals are at the end. If you see FAIL, paste that line when asking for help.
# =============================================================================

P=0; W=0; F=0
pass() { P=$((P+1)); echo "  PASS  $1"; }
warn() { W=$((W+1)); echo "  WARN  $1"; }
fail() { F=$((F+1)); echo "  FAIL  $1"; }
sec()  { echo; echo "--- $1"; }

QS="$HOME/.config/quickshell/snow"
SB="$HOME/.config/snow"
HY="$HOME/.config/hypr"

sec "Packages"
for p in hyprland hypridle hyprlock quickshell kitty nautilus mission-center sddm xorg-server mousepad mpv zenity \
         qt5-declarative qt5-quickcontrols2 qt6-declarative qt6-wayland \
         hyprpolkitagent papers file-roller 7zip ffmpegthumbnailer grim slurp wl-clipboard timeshift pacman-contrib python libnotify jq imagemagick \
         brightnessctl ddcutil playerctl pipewire pipewire-pulse wireplumber libpulse \
         networkmanager bluez bluez-utils dconf papirus-icon-theme \
         inter-font ttf-jetbrains-mono ttf-montserrat noto-fonts-emoji; do
  pacman -Qq "$p" >/dev/null 2>&1 && pass "package $p" || fail "package $p is missing"
done

sec "Quickshell files"
[ -f "$QS/shell.qml" ] && pass "shell.qml" || fail "shell.qml not found ($QS)"
[ -f "$QS/qmldir" ] && pass "qmldir" || fail "qmldir not found"
[ -f "$QS/Theme.qml" ] && pass "Theme.qml" || fail "Theme.qml not found"
if [ -f "$QS/shell.qml" ]; then
  head -1 "$QS/shell.qml" | grep -q 'UseQApplication' && pass "shell.qml has the UseQApplication pragma" \
    || warn "first line of shell.qml is not '//@ pragma UseQApplication' (the tray menu may fail)"
  # Every 'Xyz {}' used in shell.qml needs a file components/Xyz.qml
  for c in $(grep -oE '^[[:space:]]+[A-Z][A-Za-z]+ \{\}' "$QS/shell.qml" | tr -d ' {}'); do
    [ -f "$QS/components/$c.qml" ] && pass "component $c" || fail "shell.qml uses $c but components/$c.qml is missing"
  done
  # The other way: a file in components/ that shell.qml does not use (SliderRow is a helper, skip it)
  for f in "$QS"/components/*.qml; do
    n=$(basename "$f" .qml)
    [ "$n" = SliderRow ] && continue
    [ "$n" = WallpaperPreview ] && continue   # helper of ThemeMenu (loaded with a Loader)
    [ "$n" = PolkitDialog ] && continue   # loaded from shell.qml by code, not as a plain item
    [ "$n" = WorkspaceOsd ] && continue   # same: loaded by code
    grep -qE "^[[:space:]]+$n \{\}" "$QS/shell.qml" || warn "components/$n.qml is not used in shell.qml"
  done
fi
if [ -f "$SB/theme.json" ]; then
  jq -e . "$SB/theme.json" >/dev/null 2>&1 && pass "theme.json valid" || fail "theme.json is broken (invalid JSON)"
else fail "theme.json not found ($SB)"; fi
for s in screenshot killapp apply-kitty apply-gtk start-polkit switch-theme warp themes look audio set-defaults wallpaper apply-qt apply-lock install-fonts mouse-wake power backup update cleanup update-check; do
  [ -f "$SB/bin/$s.sh" ] && pass "bin/$s.sh" || warn "bin/$s.sh not found"
done

for t in "$SB"/themes/*.json; do
  [ -f "$t" ] || continue
  jq -e '.bg and .surface and .surfaceHi and .text and .muted and .accent and .tint' "$t" >/dev/null 2>&1 \
    && pass "theme $(basename "$t" .json)" || fail "theme $(basename "$t") is incomplete or broken"
done
for l in "$SB"/looks/*.json; do
  [ -f "$l" ] || continue
  jq -e '.gaps_in != null and .rounding != null and .anim_curve != null' "$l" >/dev/null 2>&1 && pass "look $(basename "$l" .json)" || fail "look $(basename "$l") is incomplete / broken"
done
[ -f "$SB/bin/wallpaper-colors.py" ] && pass "wallpaper-colors.py" || warn "wallpaper-colors.py not found"
for f in snapshot.sh backup.sh restore.sh reset.sh doctor.sh README.md; do
  [ -f "$(dirname "${BASH_SOURCE[0]}")/$f" ] && pass "tools/$f" || warn "tools/$f not found"
done
[ -f "$HOME/.config/kitty/snow-keys.conf" ] && grep -q 'snow-keys.conf' "$HOME/.config/kitty/kitty.conf" 2>/dev/null && pass "kitty copy/paste keys" || warn "kitty copy/paste keys are not set (run install.sh)"
[ -f "$SB/prompt.sh" ] && grep -q "snow/prompt.sh" "$HOME/.bashrc" 2>/dev/null && pass "colored prompt" || warn "colored prompt is not set (run install.sh)"
command -v zenity >/dev/null && pass "zenity (wallpaper picker)" || warn "zenity is missing: sudo pacman -S zenity"
[ -f "$SB/bin/theme-variant.py" ] && pass "theme-variant.py" || warn "theme-variant.py not found"
[ -f "$SB/mode" ] && pass "theme mode: $(cat "$SB/mode") / theme: $(cat "$SB/theme" 2>/dev/null) / wallpaper-colors: $(cat "$SB/autowall" 2>/dev/null)" || warn "snow/mode file not found"
[ -f "$HOME/.config/kdeglobals" ] && pass "Qt/KDE colors (kdeglobals)" || warn "kdeglobals not found (run apply-qt.sh)"
systemctl --user is-enabled snow-update-check.timer >/dev/null 2>&1 && pass "weekly update timer enabled" || warn "snow-update-check.timer is not enabled"
command -v cliphist >/dev/null && warn "cliphist is still installed (it should be removed): sudo pacman -Rns cliphist"
if command -v warp-cli >/dev/null; then
  pass "warp-cli installed"
  systemctl is-active --quiet warp-svc && pass "warp-svc active" || warn "warp-svc is not active (run: sudo systemctl enable --now warp-svc)"
else warn "warp-cli is missing (run: yay -S cloudflare-warp-bin) - the WARP button will not work"; fi

sec "Hyprland config"
[ -f "$HY/hyprland.lua" ] && pass "hyprland.lua found" || fail "hyprland.lua not found"
[ -f "$HY/theme-colors.lua" ] && pass "theme-colors.lua found" || fail "theme-colors.lua not found"
[ -f "$HY/look.lua" ] && pass "look.lua found (look: $(cat "$SB/look" 2>/dev/null))" || fail "look.lua not found (run: bash ~/.config/snow/bin/look.sh set minimal)"
if command -v luac >/dev/null && [ -f "$HY/hyprland.lua" ]; then
  luac -p "$HY/hyprland.lua" 2>/dev/null && pass "hyprland.lua syntax is OK" || fail "hyprland.lua syntax error"
fi
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null; then
  ce=$(hyprctl configerrors 2>/dev/null)
  if [ -z "$ce" ] || echo "$ce" | grep -qi 'no errors'; then pass "hyprctl configerrors is clean"
  else fail "hyprctl configerrors: $(echo "$ce" | head -3 | tr '\n' ' ')"; fi
else
  echo "  (Hyprland is not running, skipping configerrors)"
fi
b=$(sed -n 's/^local browser *= *"\(.*\)".*/\1/p' "$HY/hyprland.lua" 2>/dev/null | head -1)
if [ -n "$b" ]; then
  command -v "$b" >/dev/null && pass "Super+B browser '$b' found" || fail "Super+B browser '$b' is not in PATH (is Brave installed?)"
fi
command -v librewolf >/dev/null && pass "librewolf (Super+Shift+B)" || warn "librewolf is missing (optional)"
command -v localsend >/dev/null && pass "localsend (Super+L)" || warn "localsend is missing (Super+L will not work, optional)"
pacman -Qq polkit-kde-agent >/dev/null 2>&1 && warn "polkit-kde-agent is still installed (remove it: sudo pacman -Rns polkit-kde-agent)" || pass "polkit-kde-agent is not installed (good)"
[ -f "$SB/bin/start-polkit.sh" ] && pass "bin/start-polkit.sh" || fail "bin/start-polkit.sh not found (hyprland.lua starts it)"
grep -q 'start-polkit.sh' "$HY/hyprland.lua" 2>/dev/null && pass "hyprland.lua starts the polkit agent" || warn "hyprland.lua does not run start-polkit.sh"
qsPolkit=""
for d in /usr/lib/qt6/qml/Quickshell/Services/Polkit /usr/lib/qml/Quickshell/Services/Polkit /usr/lib/x86_64-linux-gnu/qt6/qml/Quickshell/Services/Polkit; do [ -d "$d" ] && qsPolkit=1; done
[ -f "$QS/components/PolkitDialog.qml" ] && pass "components/PolkitDialog.qml" || fail "components/PolkitDialog.qml missing"
if [ -n "$qsPolkit" ]; then
  pass "Quickshell has the Polkit module (the snow dialog is the password agent)"
  pgrep -x hyprpolkitagent >/dev/null && warn "hyprpolkitagent is also running; two agents conflict. Run: pkill hyprpolkitagent"
else
  warn "this Quickshell build has no Polkit module; hyprpolkitagent is used as the fallback"
  [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && { pgrep -x hyprpolkitagent >/dev/null && pass "hyprpolkitagent running" || warn "hyprpolkitagent not running"; }
fi
[ -n "$(find "$HOME/.local" /opt /usr/share/applications /usr/local -maxdepth 4 -iname '*abdownloadmanager*' -print -quit 2>/dev/null)" ] && pass "AB Download Manager found" || warn "AB Download Manager not found (install: bash <(curl -fsSL https://raw.githubusercontent.com/amir1376/ab-download-manager/master/scripts/install.sh))"
pacman -Q gwenview >/dev/null 2>&1 && pass "Gwenview (image viewer)" || warn "Gwenview is missing: sudo pacman -S gwenview kimageformats"
pacman -Q mpv >/dev/null 2>&1 && pass "mpv" || warn "mpv is missing: sudo pacman -S mpv"
[ -f "$HOME/.config/mpv/input.conf" ] && pass "mpv keys (~/.config/mpv/input.conf)" || warn "mpv input.conf not found (run install.sh)"
[ -f "$HOME/.config/mpv/mpv.conf" ] && pass "mpv settings (~/.config/mpv/mpv.conf)" || warn "mpv.conf not found (run: bash ~/.config/snow/bin/mpv-setup.sh)"
[ -f "$HOME/.config/mpv/scripts/uosc/main.lua" ] && pass "mpv interface uosc" || warn "uosc is not installed (run: bash ~/.config/snow/bin/mpv-setup.sh, needs internet)"
[ -f "$HOME/.config/mpv/scripts/snow-add.lua" ] && pass "mpv Add-videos button (snow-add.lua)" || warn "snow-add.lua not found (run: bash ~/.config/snow/bin/mpv-setup.sh)"
[ -f "$HOME/.config/mpv/script-opts/uosc.conf" ] && pass "uosc settings (uosc.conf)" || warn "uosc.conf not found (run: bash ~/.config/snow/bin/mpv-setup.sh)"
command -v yay >/dev/null && pass "yay" || warn "yay is missing (needed for AUR packages)"

sec "NVIDIA"
if lspci -nn 2>/dev/null | grep -qi nvidia; then
  for k in $(pacman -Qq | grep -E '^linux(-lts|-zen|-hardened|-rt)?$'); do
    pacman -Qq "$k-headers" >/dev/null 2>&1 && pass "$k-headers" || warn "$k-headers is missing (only the dkms driver needs it)"
  done
  mp=$(modinfo -n nvidia 2>/dev/null)
  if [ -n "$mp" ]; then
    pass "nvidia kernel module found: $(pacman -Qqo "$mp" 2>/dev/null || echo dkms)"
  else
    fail "nvidia kernel module not found (modinfo nvidia). Check: dkms status"
  fi
  for p in nvidia-utils egl-wayland libva-nvidia-driver linux-firmware-nvidia; do
    pacman -Qq "$p" >/dev/null 2>&1 && pass "package $p" || fail "package $p is missing"
  done
  [ -d "/usr/lib/modules/$(uname -r)" ] && pass "modules for the running kernel found" \
    || warn "modules for the running kernel ($(uname -r)) not found: the kernel was updated, please REBOOT"
  if lsmod | grep -q '^nvidia '; then pass "nvidia module loaded"; else warn "nvidia module is not loaded (check again after a reboot)"; fi
  nvidia-smi >/dev/null 2>&1 && pass "nvidia-smi works" || warn "nvidia-smi failed (reboot, or check the driver)"
else
  echo "  (no NVIDIA GPU found)"
fi

sec "SDDM login screen"
[ -x /usr/bin/sddm-greeter ] && pass "sddm-greeter found" || fail "sddm-greeter not found"
if [ -x /usr/bin/sddm-greeter ]; then
  nf=$(ldd /usr/bin/sddm-greeter 2>/dev/null | grep 'not found')
  [ -z "$nf" ] && pass "all greeter libraries found" || fail "greeter libraries missing: $(echo "$nf" | tr '\n' ' ')"
fi
T=/usr/share/sddm/themes/snow
for f in Main.qml Ring.qml metadata.desktop theme.conf; do
  [ -f "$T/$f" ] && pass "sddm theme: $f" || fail "sddm theme: $f not found"
done
[ -f "$T/background.jpg" ] && pass "sddm background.jpg" || warn "sddm background.jpg not found (no wallpaper on the login screen)"
grep -q '^import QtQuick 2.15' "$T/Main.qml" 2>/dev/null && pass "Main.qml: import QtQuick 2.15 (needed for the Qt5 greeter)" || fail "Main.qml is missing 'import QtQuick 2.15' (the Qt5 greeter will fail)"
grep -q 'QtQuick.Effects' "$T/Main.qml" 2>/dev/null && fail "Main.qml uses QtQuick.Effects (does not work in Qt5)"
if [ -f /etc/sddm.conf.d/zz-snow.conf ]; then pass "zz-snow.conf found"; else fail "/etc/sddm.conf.d/zz-snow.conf not found"; fi
last=$(grep -H '^Current=' /etc/sddm.conf.d/*.conf /etc/sddm.conf 2>/dev/null | sort -t: -k1,1 | tail -1)
case "$last" in *zz-snow.conf*) pass "theme Current=snow is the one being used" ;; *) warn "another conf file sets Current=: $last" ;; esac
grep -q '^Numlock=on' /etc/sddm.conf.d/zz-snow.conf 2>/dev/null && pass "Numlock=on" || warn "Numlock=on is not set"
systemctl is-enabled sddm >/dev/null 2>&1 && pass "sddm enabled" || fail "sddm is not enabled (run: sudo systemctl enable sddm)"
ls /usr/share/wayland-sessions/ 2>/dev/null | grep -qi hyprland && pass "Hyprland session file found" || fail "no Hyprland file in wayland-sessions"

sec "Wallpaper"
shopt -s nullglob nocaseglob
w=("$HY"/wallpaper/*.{jpg,jpeg,png,webp})
shopt -u nullglob nocaseglob
[ ${#w[@]} -gt 0 ] && pass "${#w[@]} image(s) in the wallpaper folder" || warn "~/.config/hypr/wallpaper is empty"
systemctl is-active snow-sddm-wallpaper.path >/dev/null 2>&1 && pass "snow-sddm-wallpaper.path active" || warn "snow-sddm-wallpaper.path is not active"
[ -x /usr/local/bin/snow-sddm-wallpaper ] && pass "snow-sddm-wallpaper script" || warn "snow-sddm-wallpaper script not found"

sec "Services / Bluetooth / Network"
for s in NetworkManager bluetooth; do
  systemctl is-enabled "$s" >/dev/null 2>&1 && pass "$s enabled" || fail "$s is not enabled"
done
grep -q '^AutoEnable=false' /etc/bluetooth/main.conf 2>/dev/null && pass "Bluetooth AutoEnable=false" || warn "Bluetooth AutoEnable=false is not set (Bluetooth will be ON at boot)"
id -nG | grep -qw i2c && pass "user is in the i2c group (brightness)" || warn "user is not in the i2c group (log out and in, or reboot)"

sec "Theme (kitty / GTK) and launcher"
[ -f "$HOME/.config/kitty/snow-theme.conf" ] && pass "kitty snow-theme.conf" || warn "kitty theme file not found (run apply-kitty.sh)"
grep -q 'snow-theme.conf' "$HOME/.config/kitty/kitty.conf" 2>/dev/null && pass "kitty.conf includes snow-theme.conf" || warn "kitty.conf does not have 'include snow-theme.conf'"
grep -q '^font_family' "$HOME/.config/kitty/kitty.conf" 2>/dev/null && pass "kitty font set" || warn "kitty font is not set"
[ -f "$HOME/.config/gtk-4.0/gtk.css" ] && pass "GTK4 gtk.css (Nautilus)" || warn "GTK4 gtk.css not found (run apply-gtk.sh)"
for id in bssh bvnc avahi-discover lstopo; do
  [ -f "/usr/share/applications/$id.desktop" ] || continue
  grep -q '^NoDisplay=true' "$HOME/.local/share/applications/$id.desktop" 2>/dev/null && pass "$id is hidden in the launcher" || warn "$id will show in the launcher"
done
fc-list 2>/dev/null | grep -qi 'emoji' && pass "emoji font" || warn "emoji font not found (the volume icon will not show)"

echo
[ "$F" -eq 0 ]

# ---- power setting (hypridle / nvidia sleep)
echo "== Power Setting =="
pgrep -x hypridle >/dev/null && pass "hypridle running" || warn "hypridle not running (it starts at login; or run: bash ~/.config/snow/bin/power.sh restart)"
[ -f "$HOME/.config/snow/power.json" ] && pass "power.json: $(tr -d ' \n' < "$HOME/.config/snow/power.json")" || warn "power.json not found"
if lspci -nn 2>/dev/null | grep -qi nvidia; then
  for u in nvidia-suspend nvidia-resume nvidia-hibernate; do
    systemctl is-enabled "$u.service" >/dev/null 2>&1 && pass "$u.service enabled" || warn "$u.service is not enabled (run install.sh again, then reboot)"
  done
  v=$(cat /proc/driver/nvidia/params 2>/dev/null | grep PreserveVideoMemoryAllocations | awk '{print $2}')
  [ "$v" = 1 ] && pass "PreserveVideoMemoryAllocations: 1" || warn "PreserveVideoMemoryAllocations is '${v:-?}' (needs 1; reboot after install.sh)"
fi
# ---- icon font
echo "== Icon font =="
fc-list 2>/dev/null | grep -qi "Material Symbols Rounded" && pass "Material Symbols Rounded installed" || warn "icon font missing (run: bash ~/.config/snow/bin/install-fonts.sh)"
[ -f "$HOME/.config/snow/fonts/MaterialSymbolsRounded.ttf" ] && pass "icon font file in ~/.config/snow/fonts (backed up with snow)" || warn "icon font file not found in ~/.config/snow/fonts"
# ---- mouse wake
echo "== Mouse wake from sleep =="
mw=$(bash "$HOME/.config/snow/bin/mouse-wake.sh" --check 2>&1)
if echo "$mw" | grep -q "wake now: enabled"; then pass "USB mouse can wake the PC"
elif echo "$mw" | grep -q "wake now: disabled"; then warn "USB mouse wake is OFF (run: bash ~/.config/snow/bin/mouse-wake.sh)"
else pass "mouse wake: $(echo "$mw" | head -1)"; fi
echo "================  PASS: $P   WARN: $W   FAIL: $F  ================"
