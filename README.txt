=====================================================================
 SNOW  -  Snow-Dot v2  -  README   (3 minute read)
=====================================================================

What is in this folder
  install.sh         the installer (fresh minimal Arch -> the full snow desktop)
  files/             all the config files, QML files and scripts
  docs/              guides, the change log (narrative.txt) and snow-hyprland.txt
                     (the full record: what was built, what went wrong, how it was fixed, the code of every file)
  tools/             snapshot.sh, backup.sh, restore.sh, reset.sh, doctor.sh + tools/README.md (how each one works)
                     tools/latest/ always holds exactly ONE file: the newest backup (latest.tar.gz)
  backups/           backup/ (backup.sh files), snapshot/ (snapshot.sh files), history/ (old files/ copies).
                     Everything stays inside Snow-Dot. Nothing here is deleted automatically.

Quick install (on a fresh minimal Arch, with the Snow-Dot folder in your home folder and the internet working):
  bash ~/Snow-Dot/install.sh
Backup:
  bash ~/Snow-Dot/tools/backup.sh      (full details: tools/README.md)

---------------------------------------------------------------------
 A.  BEFORE YOU FORMAT  (while your old system still works)
---------------------------------------------------------------------
 1. Keep this folder in your home folder:  ~/Snow-Dot
 2. In a terminal:   bash ~/Snow-Dot/tools/backup.sh
    -> One file is created:  ~/Snow-Dot/backups/backup/Snow-Backup-<date>.tar.gz
       (a copy is also kept in ~/Snow-Dot/tools/latest/latest.tar.gz)
    -> THE REAL LIVE COPY OF YOUR FILES COMES FROM THIS STEP. Do not skip it.
       (tools/snapshot.sh does the same, and also updates the files/ folder of Snow-Dot.)
 3. Copy that .tar.gz to a USB drive (and keep one more copy somewhere else).
 4. If your wallpaper image is in ~/.config/hypr/wallpaper/, the backup includes it
    (files/wallpaper/). The install puts the same image back.

---------------------------------------------------------------------
 B.  AFTER A MINIMAL ARCH INSTALL  (in the TTY / terminal)
---------------------------------------------------------------------
 When you install Arch, remember:
   - Make a normal user (with sudo / wheel). install.sh does not run as root.
   - You need NetworkManager. The internet must work:
         nmtui            (to connect Wi-Fi)
   - Any kernel is fine (linux / linux-lts). install.sh installs the headers by itself.

 1. Plug in the USB drive and look at it:
         lsblk
    The USB drive is often /dev/sdb1 (or sda1). Let us say it is sdb1:
         sudo mkdir -p /mnt/usb
         sudo mount /dev/sdb1 /mnt/usb
    (If the USB drive is NTFS / exFAT and does not mount, first run:  sudo pacman -S ntfs-3g exfatprogs)

 2. Copy and unpack:
         cp /mnt/usb/Snow-Backup-*.tar.gz ~/
         sudo umount /mnt/usb
         cd ~ && tar xzf Snow-Backup-*.tar.gz
         cd Snow-Dot

 3. Run it:
         bash install.sh
    It will ask for your password (sudo). It can take 15-30 minutes (NVIDIA dkms + yay + Brave).
    At the end you will see a list of FAIL / WARN items.

 4. Reboot:
         sudo reboot
    On the login screen, choose the session "Hyprland" (not the uwsm one). The wallpaper
    shows on the login screen after a few seconds (a service creates it).

 5. After you log in, in a terminal (Super+T):
         bash ~/Snow-Dot/tools/doctor.sh
    If everything is PASS, you are done. If you see WARN / FAIL, ask for help and include
    the output of those lines.

 The full output of the install is saved here:   ~/snow-install.log
 (If something goes wrong, ask for help and include the output of that file.)

---------------------------------------------------------------------
 C.  IF YOU HAVE A PROBLEM
---------------------------------------------------------------------
 NO LOGIN SCREEN / black screen / default theme
   1. Press Ctrl + Alt + F3  ->  log in with your user (TTY).
   2. Look at the error:
         journalctl -b -u sddm --no-pager | tail -40
         ldd /usr/bin/sddm-greeter | grep 'not found'
      If anything shows "not found", install that library (qt5-declarative, qt5-quickcontrols2).
   3. Test the theme (with the Qt5 greeter, the real one):
         sddm-greeter --test-mode --theme /usr/share/sddm/themes/snow
   4. To go back to the default theme:
         sudo rm /etc/sddm.conf.d/zz-snow.conf && sudo reboot
   5. If you only want the desktop (no login screen):  in the TTY, type  Hyprland

 NVIDIA / NO GPU ROW / NO BRIGHTNESS
         dkms status                 (nvidia must say "installed" for every kernel)
         nvidia-smi
         pacman -Q linux linux-lts linux-headers linux-lts-headers
      Each kernel must also have its "-headers" package. If not, run:
         sudo pacman -S linux-lts-headers      (or linux-headers)   && sudo dkms autoinstall
      Then reboot.

 SUPER+B (BROWSER) DOES NOT OPEN
         command -v brave-origin
      If nothing is shown, run:  yay -S brave-origin-bin

 PANELS ARE NOT SHOWN
         pkill qs; qs -p ~/.config/quickshell/snow
      Read the error that appears (or:  qs -p ~/.config/quickshell/snow log | tail -30 ).

 HYPRLAND CONFIG ERROR (for example "hyprland.lua:143 expected near <eof>")
         hyprctl configerrors
         sed -n 130,150p ~/.config/hypr/hyprland.lua
      Ask for help and include the output of both commands. install.sh keeps your old config under the name  hyprland.lua.before-snow-<time>.

 NO INTERNET (during the install)
      Wi-Fi:  nmtui   -> then run  bash install.sh  again. Running the script again is safe
      (it skips what is already done; the old quickshell / snow folders are moved to  .before-snow-<time> ).

 AN UNWANTED APP SHOWS IN THE LAUNCHER
      Create ~/.local/share/applications/<name>.desktop :
         [Desktop Entry]
         Type=Application
         Name=<name>
         NoDisplay=true
      (<name> = the name of the file in /usr/share/applications, without .desktop)

---------------------------------------------------------------------
 D.  EVERYDAY TASKS
---------------------------------------------------------------------
 Change colors         Super+A (Themes menu). To make your own theme: press Edit in the Themes menu, click a theme, change the name and colors, press Done.
                       (To see the colors on Nautilus:  nautilus -q  then open it again)
 Change wallpaper      Super+A, click the small picture button next to "Wallpaper", choose an image.
                       It replaces the wallpaper in ~/.config/hypr/wallpaper/ (the old one is kept once in previous/).
                       If the login screen does not change:  sudo systemctl start snow-sddm-wallpaper.service
 Reload panels         pkill qs; snow
 New backup            bash ~/Snow-Dot/tools/snapshot.sh   (updates files/ + docs, writes backups/snapshot/...)
 Backup file           bash ~/Snow-Dot/tools/backup.sh     (only one .tar.gz in backups/backup/; Snow-Dot is not changed; copy it to a USB drive)
 Restore the LAST one  bash ~/Snow-Dot/tools/restore.sh    (no file name: uses tools/latest/latest.tar.gz; every backup / snapshot replaces it)
 Restore a chosen one  bash ~/Snow-Dot/tools/restore.sh <a .tar.gz  OR  the Snow-Dot folder>   (--list shows what it finds)
                         -> asks: 1) settings only  2) full install (install.sh)
 Plain Hyprland        bash ~/Snow-Dot/tools/reset.sh      (makes a backup file first, removes the snow settings, logs you out;
                       Hyprland then starts with its own default config. To come back: tools/restore.sh,
                       or  bash ~/Snow-Dot/install.sh)
 Health check          bash ~/Snow-Dot/tools/doctor.sh

 KEYBINDS
   Super+Space  launcher         Super+Tab       Quick Settings (Dark/Light, WARP, sound output, brightness, Update/Clean, tray)
   Super+A  Themes menu (wallpaper button + Auto colors, custom themes, WINDOW LOOK; press Edit to change colors and look values)
   Super+Escape power menu
   Super+BackSpace  clock OSD        Super+S       screenshot (area)
   Super+Shift+S screenshot (full)
   Super+T / E / B / L   kitty / nautilus / Brave Origin / LocalSend
   Super+Shift+B  LibreWolf (second browser)
   Super+W close  Super+F fullscreen  Super+Shift+F float  Super+M logout

---------------------------------------------------------------------
 E.  WHAT WE LEFT OUT ON PURPOSE
---------------------------------------------------------------------
 These things are not in snow. This is by design, not a bug:
 - No lock screen.
 - Sleep / lock / screen off: Quick Settings -> power button (top right) -> Power Setting. No lock button on purpose.
 - No clipboard history.
 - No do-not-disturb.
 - No night light.
 - No notification history.
 - No wallpaper gallery. You pick one image with the button in the Themes menu (see section D).
 - No media widget.
 - No firewall.

 Other notes:
 - Download manager: AB Download Manager (from its official install script). Mousepad (pacman) is also installed.
 - Video player: mpv with the uosc interface (own keys, "Add videos" button). It is set up by ~/.config/snow/bin/mpv-setup.sh (install.sh and
   tools/restore.sh run it; it downloads uosc from GitHub). The settings are part of every backup. VLC is no longer used.
 - Polkit agent: the password window is drawn by Quickshell itself (snow style, title "Authentication" and a password box).
   hyprpolkitagent stays installed only as a fallback. The KDE agent was removed. Prompts such as 'admin://' in the file manager use it.
 - After you change the theme colors, kitty and Nautilus need to be updated by hand (it is not automatic).
 - The AUR package name for LocalSend was not verified (both localsend-bin and localsend are tried).
   If neither is found, Super+L will not work, but everything else will be fine.

---------------------------------------------------------------------
 G.  INSTALL FROM GITHUB  (instead of a USB drive, the easiest way)
---------------------------------------------------------------------
 On a new minimal Arch, after the internet works (Wi-Fi with nmtui), run only this:
     sudo pacman -S --needed git
     git clone https://github.com/snowspel/hypr.git ~/Snow-Dot && bash ~/Snow-Dot/install.sh
 Then run  sudo reboot.
 (To get the URL of any repo: open the repo on github.com -> green "Code" button -> HTTPS URL.)
 Note: if the repo is PUBLIC, everyone can see the wallpaper and all the files. No password or key is stored in any file.

---------------------------------------------------------------------
 F.  DO IT BY HAND  (without install.sh)
---------------------------------------------------------------------
 Where each file goes is written in the INDEX of docs/snow-hyprland.txt (file -> system path).
 The list of packages is in steps 2 and 3 of install.sh. You can copy files with a file manager
 (press Ctrl+H to see hidden folders), but you need a terminal for the services, the SDDM conf
 and NVIDIA. So install.sh is the recommended way.
=====================================================================
