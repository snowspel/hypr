#!/bin/bash
# =============================================================================
#  snow  -  install.sh  (v2, "Snow2ndInning")
#  Installs a full Quickshell desktop on a fresh minimal Arch + Hyprland
#  system with one command.
#
#  How to run (as a normal user, not as root):
#      bash install.sh
#
#  The script is safe to run again. Packages that are already installed are
#  skipped, and old config folders are backed up before they are replaced.
#  All output is also saved to ~/snow-install.log. If a problem happens,
#  please share that file.
#
#  What is new in this version (lessons from the earlier version):
#   - The full system is updated first (-Syu), and only then packages are
#     installed. There is no partial update.
#   - Every package is checked before install. One wrong package name does not
#     stop the whole install.
#   - Headers are installed for every installed kernel (linux, linux-lts, zen,
#     and so on). NVIDIA dkms needs them. The earlier version installed only
#     linux-headers, but the kernel was lts.
#   - The SDDM greeter uses Qt5, so qt5-declarative and qt5-quickcontrols2 are
#     installed.
#   - The SDDM config is zz-snow.conf. The Current= line in other conf files is
#     turned off. (The file that comes last in alphabetical order wins. In the
#     earlier version, the name 99- lost to theme.conf.)
#   - Brave Origin is installed from the AUR (through yay-bin). If the binary
#     is found, Super+B is set automatically.
#   - The theme and font for Kitty and Nautilus (GTK) are applied during
#     install.
#   - Useless desktop entries (bssh, bvnc, avahi-discover, lstopo) are hidden
#     from the launcher.
#   - Download manager: AB Download Manager (from its official install
#     script). Mousepad is also installed. Video player: mpv (+ uosc interface, set up by bin/mpv-setup.sh).
#   - Polkit agent: hyprpolkitagent (polkit-kde-agent is removed).
# =============================================================================

R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES="$R/files"
[ -d "$FILES" ] || FILES="$R"          # use this folder if install.sh is placed next to the files

LOG="$HOME/snow-install.log"
exec > >(tee -a "$LOG") 2>&1

WARNS=()
FAILS=()
warn() { WARNS+=("$1"); echo "  [WARN] $1"; }
fail() { FAILS+=("$1"); echo "  [FAIL] $1"; }
step() { echo; echo "=== $1 ==="; }

echo "snow install  -  $(date '+%F %T')  -  log: $LOG"

# ---------------------------------------------------------------- 0. pre-checks
step "0/11  Pre-checks"
if [ "$EUID" -eq 0 ]; then echo "Do not run as root. Run as a normal user: bash install.sh"; exit 1; fi
command -v pacman >/dev/null || { echo "This script is only for Arch Linux."; exit 1; }
command -v sudo   >/dev/null || { echo "sudo was not found. First run: su -c 'pacman -S sudo' and add your user to the wheel group."; exit 1; }

for f in quickshell/shell.qml hypr/hyprland.lua hypr/theme-colors.lua hypr/look.lua snow/looks/minimal.json sddm/snow/Main.qml \
         snow/theme.json snow/themes/Snow.json systemd/user/snow-update-check.timer system/snow-sddm-wallpaper system/snow-sddm-wallpaper.path \
         system/snow-sddm-wallpaper.service; do
  [ -f "$FILES/$f" ] || { echo "The folder is incomplete. This file was not found: $FILES/$f"; exit 1; }
done

if ! curl -fsI --max-time 10 https://archlinux.org >/dev/null 2>&1; then
  echo "The internet is not working. For Wi-Fi, use:  nmtui   (or  iwctl)  and then run this script again."
  exit 1
fi

sudo -v || exit 1
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE=$!
trap 'kill $KEEPALIVE 2>/dev/null' EXIT

# helper: check every package first, skip the ones not in the repo, install the rest
pac() {
  local ok=() miss=() p
  for p in "$@"; do
    if pacman -Si "$p" >/dev/null 2>&1; then ok+=("$p"); else miss+=("$p"); fi
  done
  [ ${#miss[@]} -gt 0 ] && warn "not found in the repo (skipped): ${miss[*]}"
  if [ ${#ok[@]} -gt 0 ]; then
    if ! sudo pacman -S --needed --noconfirm "${ok[@]}"; then
      fail "pacman install failed: ${ok[*]}"
      return 1
    fi
  fi
  return 0
}

# ---------------------------------------------------------------- 1. update
step "1/11  System update"
if ! sudo pacman -Syu --noconfirm; then
  fail "pacman -Syu failed. Check the internet and the mirrors, then run this script again."
  echo "It is not safe to continue. Stopping."
  exit 1
fi

# ---------------------------------------------------------------- 2. packages
step "2/11  Packages"
pac base-devel git curl pciutils
pac hyprland quickshell xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    hyprpolkitagent qt6-declarative qt6-wayland
pac gwenview kimageformats   # image viewer with light editing (rotate, crop, resize); kimageformats = AVIF / HEIC / JXL etc.
pac mpv   # video player (config: files/snow/mpv, set up by bin/mpv-setup.sh; zenity / unzip / inter-font come below)
pac kitty nautilus mission-center mousepad
pac grim slurp wl-clipboard swappy libnotify jq imagemagick playerctl \
    brightnessctl ddcutil i2c-tools
pac hypridle hyprlock   # screen off / lock / sleep timers (Power Setting)
pac pipewire pipewire-pulse wireplumber libpulse
pac networkmanager bluez bluez-utils
pac gvfs udisks2 ntfs-3g exfatprogs xdg-user-dirs
pac dconf papirus-icon-theme
# Small apps pack: PDF reader, archive manager (Nautilus 'Extract here'), thumbnails for videos / WebP / HEIC
pac papers file-roller 7zip unrar unzip zip ffmpegthumbnailer webp-pixbuf-loader libheif xdg-utils
pac timeshift pacman-contrib python rsync zenity   # backup / update-check / wallpaper-colors / wallpaper picker
pac inter-font ttf-jetbrains-mono ttf-montserrat noto-fonts noto-fonts-emoji
# Polkit agent: only hyprpolkitagent. If the old KDE one is installed, remove it (two agents should not run together).
if pacman -Qq polkit-kde-agent >/dev/null 2>&1 && pacman -Qq hyprpolkitagent >/dev/null 2>&1; then
  sudo pacman -Rns --noconfirm polkit-kde-agent || warn "Could not remove polkit-kde-agent. Remove it manually: sudo pacman -Rns polkit-kde-agent"
fi
# SDDM and its greeter (Qt5!)  -> without the qt5 libraries, the login screen does not appear (sddm-helper exit 127)
pac sddm xorg-server qt5-declarative qt5-quickcontrols2 qt5-graphicaleffects

# cliphist (clipboard history) is no longer needed: if it is installed, remove it and delete the old history
if pacman -Qq cliphist >/dev/null 2>&1; then sudo pacman -Rns --noconfirm cliphist || warn "Could not remove cliphist"; fi
rm -rf "$HOME/.cache/cliphist"

# ---------------------------------------------------------------- 3. NVIDIA
step "3/11  NVIDIA driver"
if lspci -nn 2>/dev/null | grep -qi 'nvidia'; then
  echo "NVIDIA GPU found."
  # If the kernel module already exists (from a package or from dkms), do NOT install another driver package
  # (this causes a conflict: with --noconfirm, pacman answers "No" to the conflict and the whole transaction fails).
  modpath=$(modinfo -n nvidia 2>/dev/null)
  if [ -n "$modpath" ]; then
    owner=$(pacman -Qqo "$modpath" 2>/dev/null)
    echo "The nvidia kernel module already exists: ${owner:-dkms}  ($modpath)"
  else
    HEADERS=()
    for k in $(pacman -Qq | grep -E '^linux(-lts|-zen|-hardened|-rt)?$'); do
      HEADERS+=("$k-headers")
    done
    if [ ${#HEADERS[@]} -eq 0 ]; then
      warn "No linux kernel package was found (custom kernel?). Install the headers manually."
    else
      echo "Headers for the installed kernels: ${HEADERS[*]}"
      pac "${HEADERS[@]}"
    fi
    pac nvidia-open-dkms
  fi
  # the rest, one by one (so that if one fails, the others are not stopped)
  for p in nvidia-utils egl-wayland libva-nvidia-driver linux-firmware-nvidia; do pac "$p"; done
  # modeset/fbdev + keep the video memory when the PC sleeps (otherwise the screen can be broken after wake-up)
  printf 'options nvidia_drm modeset=1 fbdev=1\noptions nvidia NVreg_PreserveVideoMemoryAllocations=1\n' | sudo tee /etc/modprobe.d/snow-nvidia.conf >/dev/null
  for u in nvidia-suspend nvidia-resume nvidia-hibernate; do
    systemctl cat "$u.service" >/dev/null 2>&1 && sudo systemctl enable "$u.service" >/dev/null 2>&1 && echo "enabled $u.service"
  done
  if command -v dkms >/dev/null && [ -z "$modpath" ]; then
    echo "--- dkms status ---"
    dkms status
    want=${#HEADERS[@]}
    have=$(dkms status 2>/dev/null | grep -ci 'nvidia.*installed')
    if [ "$have" -lt "$want" ]; then
      warn "dkms: nvidia is needed on $want kernel(s), but it is 'installed' on only $have. After reboot, check 'dkms status'. If it is not fixed, run: sudo dkms autoinstall"
    fi
  fi
else
  echo "No NVIDIA GPU found, skipping the driver."
fi

# ---------------------------------------------------------------- 4. AUR
step "4/11  AUR + extra apps (yay, Brave Origin, LibreWolf, LocalSend, AB Download Manager)"
if ! command -v yay >/dev/null; then
  tmp=$(mktemp -d)
  if git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
     && ( cd "$tmp/yay-bin" && makepkg -si --noconfirm ); then
    echo "yay installed."
  else
    fail "yay install failed (AUR or internet problem?). Later, run: git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si"
  fi
  rm -rf "$tmp"
fi
if command -v yay >/dev/null; then
  if ! command -v brave-origin >/dev/null; then
    yay -S --needed --noconfirm brave-origin-bin || fail "brave-origin-bin install failed. Later, run: yay -S brave-origin-bin"
  fi
  # LibreWolf: second browser (privacy-focused). Brave Origin stays the default browser.
  if ! command -v librewolf >/dev/null; then
    yay -S --needed --noconfirm librewolf-bin || warn "LibreWolf install failed (optional). Try later: yay -S librewolf-bin"
  fi
  # LocalSend: the exact package name is not verified, so we try both (optional)
  if ! command -v localsend >/dev/null; then
    yay -S --needed --noconfirm localsend-bin || yay -S --needed --noconfirm localsend \
      || warn "LocalSend install failed (optional). Super+L will not work until it is installed."
  fi
fi

# Cloudflare WARP (the WARP button in Quick Settings uses it). The warp-svc service must be started.
if command -v yay >/dev/null; then
  if ! command -v warp-cli >/dev/null; then
    yay -S --needed --noconfirm cloudflare-warp-bin || warn "cloudflare-warp-bin install failed. Later, run: yay -S cloudflare-warp-bin"
  fi
  if command -v warp-cli >/dev/null; then
    sudo systemctl enable --now warp-svc 2>&1 | tail -n 2 || warn "Could not enable warp-svc"
  fi
fi

# AB Download Manager: your own install method (the official script). First we check if it is already installed.
# (The exact binary / desktop file name is not verified, so we search for any file with 'abdownloadmanager' in its name.)
abdm_found=$(find "$HOME/.local" /opt /usr/share/applications /usr/local -maxdepth 4 -iname '*abdownloadmanager*' -print -quit 2>/dev/null)
if [ -z "$abdm_found" ]; then
  echo "Installing AB Download Manager (official script)..."
  bash <(curl -fsSL https://raw.githubusercontent.com/amir1376/ab-download-manager/master/scripts/install.sh) \
    || warn "AB Download Manager install failed. Later, run this manually: bash <(curl -fsSL https://raw.githubusercontent.com/amir1376/ab-download-manager/master/scripts/install.sh)"
else
  echo "AB Download Manager is already installed: $abdm_found"
fi

# ---------------------------------------------------------------- 5. services
step "5/11  Services"
sudo systemctl enable NetworkManager bluetooth systemd-timesyncd 2>&1 | tail -n 3

# Bluetooth should not be ON at boot:  /etc/bluetooth/main.conf  [Policy]  AutoEnable=false
BT=/etc/bluetooth/main.conf
if [ -f "$BT" ]; then
  sudo sed -i 's/^#\?[[:space:]]*AutoEnable=.*/AutoEnable=false/' "$BT"
  if ! grep -q '^AutoEnable=false' "$BT"; then
    if grep -q '^\[Policy\]' "$BT"; then sudo sed -i '/^\[Policy\]/a AutoEnable=false' "$BT"
    else printf '\n[Policy]\nAutoEnable=false\n' | sudo tee -a "$BT" >/dev/null; fi
  fi
  grep -q '^AutoEnable=false' "$BT" && echo "Bluetooth AutoEnable=false set." || warn "Could not set Bluetooth AutoEnable."
fi

# i2c for ddcutil (brightness)
getent group i2c >/dev/null || sudo groupadd i2c
sudo usermod -aG i2c "$USER"
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null

xdg-user-dirs-update 2>/dev/null || true

# ---------------------------------------------------------------- 6. files
step "6/11  Snow files (Quickshell, scripts, Hyprland)"
TS=$(date +%s)
mkdir -p "$HOME/.config" "$HOME/Pictures/Screenshots"
for d in "$HOME/.config/quickshell/snow" "$HOME/.config/snow"; do
  if [ -d "$d" ]; then mv "$d" "$d.before-snow-$TS"; echo "old $d -> $d.before-snow-$TS"; fi
done
mkdir -p "$HOME/.config/quickshell/snow" "$HOME/.config/snow" "$HOME/.config/hypr/wallpaper"
cp -r "$FILES"/quickshell/. "$HOME/.config/quickshell/snow/"
[ -f "$HOME/.config/snow/power.json" ] && cp "$HOME/.config/snow/power.json" "/tmp/snow-power.keep"   # keep the user's Power Setting
cp -r "$FILES"/snow/.       "$HOME/.config/snow/"
[ -f /tmp/snow-power.keep ] && mv /tmp/snow-power.keep "$HOME/.config/snow/power.json"
chmod +x "$HOME"/.config/snow/bin/*.sh 2>/dev/null
bash "$HOME/.config/snow/bin/mpv-setup.sh" </dev/null || warn "mpv setup failed (later: bash ~/.config/snow/bin/mpv-setup.sh)"   # keys, settings, Add-videos button, uosc
bash "$HOME/.config/snow/bin/mouse-wake.sh" || warn "mouse-wake.sh failed (the mouse may not wake the PC from sleep; run it again later)"
bash "$HOME/.config/snow/bin/install-fonts.sh" || warn "icon font install failed (icons will be empty boxes)"
chmod +x "$HOME"/.config/snow/bin/*.sh 2>/dev/null

# weekly update-check timer (user systemd)
mkdir -p "$HOME/.config/systemd/user"
cp "$FILES"/systemd/user/snow-update-check.* "$HOME/.config/systemd/user/"
systemctl --user daemon-reload 2>/dev/null
systemctl --user enable --now snow-update-check.timer 2>&1 | tail -n 2 || warn "Could not enable the update timer (after login, run: systemctl --user enable --now snow-update-check.timer)"

for f in hyprland.lua theme-colors.lua look.lua; do
  [ -f "$HOME/.config/hypr/$f" ] && cp "$HOME/.config/hypr/$f" "$HOME/.config/hypr/$f.before-snow-$TS"
  cp "$FILES/hypr/$f" "$HOME/.config/hypr/$f"
done

# Wallpaper: the user's image (files/wallpaper) or an image in hypr/wallpaper, otherwise a simple gradient
shopt -s nullglob nocaseglob
WP=("$HOME"/.config/hypr/wallpaper/*.{jpg,jpeg,png,webp})
if [ ${#WP[@]} -eq 0 ]; then
  SRC=("$FILES"/wallpaper/*.{jpg,jpeg,png,webp} "$FILES"/hypr/wallpaper/*.{jpg,jpeg,png,webp})
  if [ ${#SRC[@]} -gt 0 ]; then
    cp "${SRC[@]}" "$HOME/.config/hypr/wallpaper/"
    echo "Wallpaper copied: ${SRC[*]}"
  else
    convert -size 2560x1440 gradient:'#1e1e2e-#2f3050' "$HOME/.config/hypr/wallpaper/wallpaper.jpg" \
      && echo "No wallpaper was found, so a simple gradient was created. Put your own image in ~/.config/hypr/wallpaper/ ." \
      || warn "Could not create the default wallpaper."
  fi
fi
shopt -u nullglob nocaseglob

# alias
grep -q "alias snow=" "$HOME/.bashrc" 2>/dev/null || \
  echo "alias snow='qs -p ~/.config/quickshell/snow'" >> "$HOME/.bashrc"
# colored prompt (follows the theme colors)
grep -q "snow/prompt.sh" "$HOME/.bashrc" 2>/dev/null || \
  echo '[ -f ~/.config/snow/prompt.sh ] && . ~/.config/snow/prompt.sh' >> "$HOME/.bashrc"

# Browser: set Super+B to the first binary that is found
BROWSER=""
for b in brave-origin brave-origin-beta brave-origin-nightly brave; do
  command -v "$b" >/dev/null && { BROWSER="$b"; break; }
done
if [ -n "$BROWSER" ]; then
  sed -i "s|^local browser .*|local browser     = \"$BROWSER\"|" "$HOME/.config/hypr/hyprland.lua"
  echo "Super+B -> $BROWSER"
else
  warn "Brave binary was not found. Super+B will not work. Later, run: yay -S brave-origin-bin"
fi

# ---------------------------------------------------------------- 7. SDDM
step "7/11  SDDM login screen"
sudo mkdir -p /usr/share/sddm/themes/snow /etc/sddm.conf.d
sudo cp -r "$FILES"/sddm/snow/. /usr/share/sddm/themes/snow/
# SDDM reads the files in conf.d in ALPHABETICAL order, and the LAST ONE WINS.
# Digits come before letters: "99-snow.conf"  <  "theme.conf"  (so 99- was wrong, and theme.conf won).
# So the name is "zz-snow.conf" (nothing comes after z), and the Current= line in other conf files is turned off.
sudo rm -f /etc/sddm.conf.d/99-snow.conf
sudo tee /etc/sddm.conf.d/zz-snow.conf >/dev/null <<'EOF_SDDM'
[General]
Numlock=on

[Theme]
Current=snow
EOF_SDDM
TSF=$(date +%s)
for f in /etc/sddm.conf.d/*.conf /etc/sddm.conf; do
  [ -f "$f" ] || continue
  [ "$f" = /etc/sddm.conf.d/zz-snow.conf ] && continue
  if grep -q '^[[:space:]]*Current=' "$f"; then
    sudo cp "$f" "$f.before-snow-$TSF"          # backup (it does not end in .conf, so SDDM does not read it)
    sudo sed -i 's/^\([[:space:]]*Current=\)/#\1/' "$f"
    echo "  Turned off Current= in $f (backup: $f.before-snow-$TSF)"
  fi
done
sudo systemctl enable sddm

# ---------------------------------------------------------------- 8. login wallpaper service
step "8/11  Login wallpaper sync service"
tmpd=$(mktemp -d)
sed "s|__HOME__|$HOME|g" "$FILES/system/snow-sddm-wallpaper"      > "$tmpd/snow-sddm-wallpaper"
sed "s|__HOME__|$HOME|g" "$FILES/system/snow-sddm-wallpaper.path" > "$tmpd/snow-sddm-wallpaper.path"
sudo install -m 755 "$tmpd/snow-sddm-wallpaper" /usr/local/bin/snow-sddm-wallpaper
sudo install -m 644 "$tmpd/snow-sddm-wallpaper.path" "$FILES/system/snow-sddm-wallpaper.service" /etc/systemd/system/
rm -rf "$tmpd"
sudo systemctl daemon-reload
sudo systemctl enable --now snow-sddm-wallpaper.path
sudo systemctl start snow-sddm-wallpaper.service || warn "The login wallpaper service failed the first time (ImageMagick or wallpaper problem?)."
[ -f /usr/share/sddm/themes/snow/background.jpg ] || warn "SDDM background.jpg was not created. The login screen will not show a wallpaper."

# ---------------------------------------------------------------- 9. theme (kitty + GTK)
step "9/11  Kitty + Nautilus (GTK) theme"
mkdir -p "$HOME/.config/kitty"
touch "$HOME/.config/kitty/kitty.conf"
grep -q '^font_family' "$HOME/.config/kitty/kitty.conf" || printf 'font_family      JetBrains Mono\nfont_size        11.0\n' >> "$HOME/.config/kitty/kitty.conf"
grep -q 'snow-theme.conf' "$HOME/.config/kitty/kitty.conf" || echo 'include snow-theme.conf' >> "$HOME/.config/kitty/kitty.conf"
cp "$HOME/.config/snow/kitty-keys.conf" "$HOME/.config/kitty/snow-keys.conf"
grep -q 'snow-keys.conf' "$HOME/.config/kitty/kitty.conf" || echo 'include snow-keys.conf' >> "$HOME/.config/kitty/kitty.conf"
bash "$HOME/.config/snow/bin/apply-kitty.sh" || warn "apply-kitty.sh failed"
bash "$HOME/.config/snow/bin/apply-gtk.sh"   || warn "apply-gtk.sh failed"

# Old versions forced a Brave theme with a policy file. Remove it (Brave keeps its own theme settings now).
for d in /etc/brave/policies/managed /etc/brave-origin/policies/managed; do
  if [ -f "$d/snow.json" ]; then sudo rm -f "$d/snow.json"; echo "removed old Brave policy: $d/snow.json"; fi
done
bash "$HOME/.config/snow/bin/apply-qt.sh"    || warn "apply-qt.sh failed"
bash "$HOME/.config/snow/bin/apply-lock.sh"  || warn "apply-lock.sh failed"
# (The dark/light mode is applied again at login by switch-theme.sh --restore in the Hyprland autostart)

# ---------------------------------------------------------------- 10. launcher cleanup
step "10/11  Hiding useless entries from the launcher"
# We do not touch the file in /usr/share (it would come back after an update). A user-level NoDisplay copy stays.
mkdir -p "$HOME/.local/share/applications"
for id in bssh bvnc avahi-discover lstopo; do
  src=/usr/share/applications/$id.desktop
  [ -f "$src" ] || continue
  name=$(grep -m1 '^Name=' "$src" | cut -d= -f2-)
  printf '[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\n' "${name:-$id}" > "$HOME/.local/share/applications/$id.desktop"
  echo "hidden: $id"
done

# default applications (browser, PDF, archives, video, text)
bash "$HOME/.config/snow/bin/set-defaults.sh" || warn "set-defaults.sh failed"

# ---------------------------------------------------------------- 11. verify
step "11/11  Final check"
if [ -f "$R/tools/doctor.sh" ]; then
  bash "$R/tools/doctor.sh" || true
fi

echo
echo "================================================================"
if [ ${#FAILS[@]} -eq 0 ] && [ ${#WARNS[@]} -eq 0 ]; then
  echo " All good. Now REBOOT:  sudo reboot"
else
  [ ${#FAILS[@]} -gt 0 ] && { echo " FAIL (important):"; printf '   - %s\n' "${FAILS[@]}"; }
  [ ${#WARNS[@]} -gt 0 ] && { echo " WARN:";          printf '   - %s\n' "${WARNS[@]}"; }
  echo
  echo " Please check the items above. Then reboot:  sudo reboot"
fi
echo " On the login screen, choose the 'Hyprland' session (not the uwsm one)."
echo " If something does not work, please send this file:  $LOG"
echo "================================================================"
