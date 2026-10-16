# tools/ - the maintenance scripts of Snow-Dot

Everything the snow desktop needs for backup, restore, reset and health checks lives here.
All scripts find the Snow-Dot folder by themselves (it is the parent of `tools/`), so the Snow-Dot
folder can be anywhere. Run every script as a **normal user** (not root). They ask for `sudo` only
where it is really needed (login screen, package install).

## Folder layout

```
Snow-Dot/
├─ install.sh            the installer (fresh Arch -> full snow desktop)
├─ files/                every config / QML / script file that goes onto the system
├─ docs/                 guides, the change log (narrative.txt) and the full record (snow-hyprland.txt)
├─ tools/                this folder
│   ├─ snapshot.sh       copy the LIVE system into Snow-Dot/files + write a snapshot file
│   ├─ backup.sh         write ONE backup file only (Snow-Dot is not changed)
│   ├─ restore.sh        put snow back from a backup file or from the Snow-Dot folder
│   ├─ reset.sh          go back to plain Hyprland (makes a backup first)
│   ├─ doctor.sh         health check (changes nothing)
│   ├─ install.sh        small wrapper that runs ../install.sh
│   └─ latest/           holds exactly ONE file: latest.tar.gz (the newest backup / snapshot)
└─ backups/
    ├─ backup/           files made by backup.sh (and the "before reset" files of reset.sh)
    ├─ snapshot/         files made by snapshot.sh
    └─ history/          the old files/ folder, saved just before each snapshot
```

Nothing is saved outside `Snow-Dot/`. Nothing in `backups/` is deleted automatically, so delete old
files by hand when you do not need them. `backups/` and `tools/latest/` are listed in `.gitignore`,
so they stay out of your manual GitHub uploads. No script pushes anything to GitHub.

## Quick reference

| I want to ...                                   | Command                                          |
|-------------------------------------------------|--------------------------------------------------|
| save my live desktop into Snow-Dot            | `bash ~/Snow-Dot/tools/snapshot.sh`              |
| make one backup file (e.g. before formatting)   | `bash ~/Snow-Dot/tools/backup.sh`                |
| restore the newest backup                       | `bash ~/Snow-Dot/tools/restore.sh`               |
| restore a chosen file                           | `bash ~/Snow-Dot/tools/restore.sh <file.tar.gz>` |
| see which backups exist                         | `bash ~/Snow-Dot/tools/restore.sh --list`        |
| check that everything works                     | `bash ~/Snow-Dot/tools/doctor.sh`                |
| go back to plain Hyprland                       | `bash ~/Snow-Dot/tools/reset.sh`                 |
| install everything on a fresh system            | `bash ~/Snow-Dot/install.sh`                     |

Before you format a disk: run `backup.sh`, then copy `tools/latest/latest.tar.gz` (or the file in
`backups/backup/`) to a USB drive or another disk. A backup that stays on the disk you format is lost.

## snapshot.sh

**What it does.** Copies the files of your running system into `Snow-Dot/files/` so the repository
matches what you really use. Then it rebuilds `docs/snow-hyprland.txt`, runs `doctor.sh`, writes a
snapshot file. It never runs git; GitHub uploads are done by hand.

**What it copies** (from -> to):
- `~/.config/quickshell/snow` -> `files/quickshell`
- `~/.config/snow` (themes, looks, state, scripts, icon font, mpv files) -> `files/snow`
- `~/.config/hypr/*.lua` -> `files/hypr`
- `~/.config/hypr/wallpaper/*` -> `files/wallpaper`
- `~/.config/mpv` (mpv.conf, input.conf, snow-add.lua, uosc.conf) -> `files/snow/mpv`
- `~/.config/systemd/user/snow-update-check.*` -> `files/systemd/user`
- `/usr/share/sddm/themes/snow` and the login wallpaper service -> `files/sddm`, `files/system`
- GTK / Qt colors, kitty, mpv, default apps, `~/.bashrc`, `.gitconfig`, desktop entries -> `files/extras/home`
- app settings (`dconf dump`) -> `files/extras/dconf.ini`
- package lists (`pacman -Qqen`, `pacman -Qqem`) and system info -> `files/extras/`

**Where the output goes.**
- `backups/snapshot/Snow-Snapshot-<date>.tar.gz` - the snapshot file
- `backups/history/files-before-<date>.tar.gz` - the previous `files/` folder (so you can undo a bad snapshot)
- `tools/latest/latest.tar.gz` - a copy of the newest file (replaces the old one)

**Options.** `--backup` switches to backup mode (see backup.sh). An optional argument is a file name
to use instead of the default one.

## backup.sh

**What it does.** The same engine as `snapshot.sh --backup`. It works on a temporary copy, so your
Snow-Dot folder is not changed. Use it when you only want a file.

**Where the output goes.**
- `backups/backup/Snow-Backup-<date>.tar.gz`
- `tools/latest/latest.tar.gz` (a copy; replaces the old one)

**Inside the file.** The same Snow-Dot shape as the repository: `install.sh`, `files/`, `docs/`,
`tools/`. So the file can be unpacked and used like a normal Snow-Dot folder, or given to `restore.sh`.
Browser profiles, documents and pictures are not included.

## restore.sh

**What it does.** Puts snow back on a system. It accepts a backup / snapshot file or a Snow-Dot folder.
With no argument it uses `tools/latest/latest.tar.gz`. It refuses a file that contains no snow settings
(for example one made after a reset) and prints the list of good files instead.

**Steps.**
1. Detects the kind of the source (`OK` = has `files/snow/themes`, `EMPTY` = no settings).
2. Asks: **1) settings only** (fast, programs stay as they are) or **2) full install** (runs `install.sh` first, then the settings).
3. Asks for a final `y` before it changes anything.
4. Copies the settings back: `~/.config/quickshell/snow`, `~/.config/snow`, `~/.config/hypr`, wallpaper,
   systemd timer, GTK / Qt / kitty / mpv files, `.bashrc`, desktop entries, dconf settings.
5. Re-applies the saved theme, fills in anything mpv is missing (uosc, config), reinstalls the icon font,
   restarts the panels (if Hyprland is running) and starts the sleep / lock timers.
6. Optionally restores the login screen (asks first, needs `sudo`).

**Examples.**
```
bash ~/Snow-Dot/tools/restore.sh                                  # newest backup
bash ~/Snow-Dot/tools/restore.sh ~/Snow-Dot/backups/backup/Snow-Backup-2026-10-16_12-00.tar.gz
bash ~/Snow-Dot/tools/restore.sh ~/Snow-Dot                       # from the folder itself
bash ~/Snow-Dot/tools/restore.sh --list                           # show what can be restored
```
It also works from a text console (Ctrl+Alt+F3) if the desktop does not start.

## reset.sh

**What it does.** Returns Hyprland to its plain default, like a new install. Your programs and files stay;
nothing is uninstalled and the Snow-Dot folder is not touched.

**Steps.**
1. You must type `RESET` to continue.
2. It makes a backup first: `backups/backup/Snow-Backup-before-reset-<date>.tar.gz`
   (and stops if that backup fails or has no `hyprland.lua`).
3. It removes the snow settings: Hyprland config, Quickshell panels, `~/.config/snow`, kitty / GTK / Qt
   colors, the mpv config and the `snow` lines in `.bashrc`.
4. Optionally (asks first, needs `sudo`) puts the login screen back to the SDDM default.
5. Optionally logs you out, so Hyprland starts with its own default config.

**To come back to snow:** `bash ~/Snow-Dot/tools/restore.sh` (the before-reset file is now the newest one)
or `bash ~/Snow-Dot/install.sh`.

## doctor.sh

**What it does.** Reads the system and prints one line per check: `PASS`, `WARN` or `FAIL`, with totals at
the end. It changes nothing. It checks packages, Quickshell files, theme / look files, the icon font, fonts,
mpv and uosc, kitty keys, the update timer, WARP, the login screen service and the tools in this folder.
When something fails, the line says how to fix it. `install.sh` runs it at the end, and `snapshot.sh`
shows the last lines of its output.

## install.sh (in this folder)

A two-line wrapper that runs `../install.sh`, so the installer can be started from here as well.
The real installer is `Snow-Dot/install.sh`. It is safe to run again, writes its log to
`~/snow-install.log`, and moves old config folders to `<name>.before-snow-<time>` before replacing them.

## Good to know

- `tools/backup.sh` (this folder) is a **settings** backup. It is not the same as
  `~/.config/snow/bin/backup.sh`, which is the Timeshift **system** backup used by the Quick Settings menu
  and by `update.sh`.
- A file in `backups/` is a normal `.tar.gz`. You can look inside with `tar -tzf <file> | less`.
- If you move the Snow-Dot folder, nothing needs to be changed. The scripts always use their own location.
- To start fresh on a new PC: copy Snow-Dot (or just `latest.tar.gz`) to it, then run
  `bash tools/restore.sh` and choose **2) full install**, or run `bash install.sh` and then `bash tools/restore.sh`.
