#!/bin/bash
# =============================================================================
#  mpv-customise.sh  -  snow mpv setup for any Linux PC (self-contained)
#  Run:   bash mpv-customise.sh          (installs / updates everything)
#         bash mpv-customise.sh --update (also re-downloads the uosc interface)
#  What it does:
#   - installs mpv, zenity, curl, unzip, inter-font with pacman if they are missing (Arch); other distros: install them by hand
#   - backs up your old mpv config to ~/.config/mpv-backup-<time>
#   - writes keys (input.conf), settings (mpv.conf), the "Add videos" button script and the uosc settings
#   - downloads the uosc interface (official GitHub release)
#  Safe to run again. Needs internet for uosc.
# =============================================================================
M="$HOME/.config/mpv"
TS=$(date +%Y%m%d-%H%M%S)

echo "== 1/4 packages"
if command -v pacman >/dev/null; then
  miss=""
  for p in mpv zenity curl unzip inter-font; do pacman -Qq "$p" >/dev/null 2>&1 || miss="$miss $p"; done
  if [ -n "$miss" ]; then echo "installing:$miss"; sudo pacman -S --needed --noconfirm $miss || echo "WARN: package install failed, install by hand:$miss"; else echo "all packages present"; fi
else
  echo "WARN: no pacman here. Please install mpv, zenity, curl, unzip (and the Inter font) with your package manager."
fi

echo "== 2/4 backup of the old config"
mkdir -p "$M/scripts" "$M/script-opts"
B="$HOME/.config/mpv-backup-$TS"
for f in input.conf mpv.conf script-opts/uosc.conf scripts/snow-add.lua; do
  [ -f "$M/$f" ] && { mkdir -p "$B/$(dirname "$f")"; cp -a "$M/$f" "$B/$f"; }
done
[ -d "$B" ] && echo "old files saved in $B" || echo "nothing to back up"

echo "== 3/4 writing the config"
cat > "$M/input.conf" << 'SNOW_EOF'
# snow: mpv keys  (copied to ~/.config/mpv/input.conf by install.sh)
# ===== My custom keybindings =====
# osd-msg = show the exact time after a seek (format: osd-status-msg in mpv.conf)
UP          add volume 5
DOWN        add volume -5
LEFT        osd-msg seek -5 ; script-binding uosc/flash-timeline
RIGHT       osd-msg seek 5 ; script-binding uosc/flash-timeline
Shift+LEFT  osd-msg seek -30 ; script-binding uosc/flash-timeline
Shift+RIGHT osd-msg seek 30 ; script-binding uosc/flash-timeline
Ctrl+LEFT   playlist-prev
Ctrl+RIGHT  playlist-next
# playlist menu (uosc). Old text-list version:  a  show-text "${playlist}" 6000
a           script-binding uosc/playlist
Ctrl+UP     add speed 0.1
Ctrl+DOWN   add speed -0.1
Ctrl+r      set speed 1.0
Alt+LEFT    osd-msg frame-back-step ; script-binding uosc/flash-timeline
Alt+RIGHT   osd-msg frame-step ; script-binding uosc/flash-timeline
Ctrl+w      quit
SPACE       cycle pause

# Audio track: next track (wraps around), and make sure sound is not muted
z           set mute no ; cycle audio
Shift+z     script-binding uosc/audio
# Subtitles: s = next subtitle track (off -> track 1 -> track 2 -> off). It also switches subtitles visible again.
s           set sub-visibility yes ; cycle sub
Shift+s     script-binding uosc/subtitles
# Fullscreen
f           cycle fullscreen
# Mute
m           cycle mute
# Show playback progress
o           show-progress
# Shuffle current playlist
x           playlist-shuffle

# ----- keys that mpv has by default and we want to keep (needed because defaults are off) -----
q           quit
ESC         set fullscreen no
i           script-binding stats/display-stats-toggle
# mouse
MBTN_LEFT       cycle pause
MBTN_LEFT_DBL   cycle fullscreen
MBTN_RIGHT      script-binding uosc/menu
WHEEL_UP        add volume 5
WHEEL_DOWN      add volume -5
SNOW_EOF
cat > "$M/mpv.conf" << 'SNOW_EOF'
# snow: mpv settings  (copied to ~/.config/mpv/mpv.conf by install.sh)
save-position-on-quit=no      # do not remember where a video stopped
resume-playback=no            # always start from the beginning (also ignores old saved positions)
keep-open=yes                 # stays open on the last frame (does not close by itself)
hwdec=auto-safe               # use the graphics card for decoding when it is safe
volume-max=130
sub-auto=fuzzy                # loads subtitle files with a similar name
screenshot-directory=~/Pictures
autofit-larger=90%x90%
osd-font=Inter                # font for the on-screen text and the uosc interface (inter-font is installed by install.sh)
osd-font-size=32
osd-border-size=2
osd-duration=1500
# text shown after Left/Right seek and on key o  (time / total / percent)
osd-status-msg="${time-pos} / ${duration}   (${percent-pos}%)"
# modern interface (uosc): it draws its own controls, so the built-in bar and the window frame are off.
# If uosc is not installed, mpv still shows its normal controls (we do NOT set osc=no here; uosc switches it off by itself).
osd-bar=no
border=no
# ---- keys: ignore mpv's own default keys; only input.conf works (a key not in input.conf does nothing)
input-default-bindings=no
input-builtin-bindings=no
# ---- subtitles: always visible when a track is selected; pick by language if present
sub-visibility=yes
sid=auto
slang=en,eng,hi,hin
# ---- audio: pick by language, load matching external audio files, try PipeWire first
aid=auto
alang=hi,hin,en,eng
audio-file-auto=fuzzy
ao=pipewire,pulse,alsa
mute=no
SNOW_EOF
cat > "$M/scripts/snow-add.lua" << 'SNOW_EOF'
-- snow: "Add videos to playlist" button
-- Called by the uosc button:  script-message snow-add-files
-- Opens a GTK file picker (zenity, select many files) and appends the chosen files to the CURRENT playlist.
-- If nothing is playing, the first file starts playing. If zenity is missing, uosc's own file browser opens instead
-- (there: Ctrl+Enter or Ctrl+click on a file adds it to the playlist).

local mp = require 'mp'
local utils = require 'mp.utils'

local function add_files()
    local args = {
        'zenity', '--file-selection', '--multiple',
        '--title=Add videos to the playlist',
        '--separator=\n',
        '--file-filter=Videos | *.mkv *.mp4 *.avi *.mov *.webm *.m4v *.flv *.wmv *.ts *.mpg *.mpeg *.MKV *.MP4 *.AVI *.MOV *.WEBM',
        '--file-filter=Audio | *.mp3 *.flac *.m4a *.ogg *.opus *.wav',
        '--file-filter=All files | *',
    }
    -- open the picker in the folder of the file that is playing
    local path = mp.get_property('path')
    if path and not path:find('^%a[%w+.-]*://') then
        local dir = utils.split_path(utils.join_path(mp.get_property('working-directory') or '', path))
        if dir and dir ~= '' then args[#args + 1] = '--filename=' .. dir end
    end

    mp.command_native_async({
        name = 'subprocess', args = args, capture_stdout = true, playback_only = false,
    }, function(success, res)
        if not success or not res or res.status < 0 or res.status > 1 then
            -- zenity not installed / crashed: use uosc's file browser
            mp.osd_message('zenity not found: use Ctrl+Enter in this list to add a file', 4)
            mp.commandv('script-binding', 'uosc/open-file')
            return
        end
        if res.status == 1 then return end   -- cancelled
        local n = 0
        for line in (res.stdout or ''):gmatch('[^\r\n]+') do
            mp.commandv('loadfile', line, 'append-play')   -- append; starts playing only if nothing is playing
            n = n + 1
        end
        if n > 0 then mp.osd_message('Added ' .. n .. ' file' .. (n > 1 and 's' or '') .. ' to the playlist', 3) end
    end)
end

mp.register_script_message('snow-add-files', add_files)
SNOW_EOF
cat > /tmp/snow-uosc.conf.$$ << 'SNOW_EOF'
# snow: uosc settings (copied to ~/.config/mpv/script-opts/uosc.conf)
# Bottom buttons, left to right: menu | subtitles, audio, video (only when the file has them) | Add videos, Playlist | prev, next, shuffle, loop, speed | fullscreen
controls=menu,gap,<video,audio>subtitles,<has_many_audio>audio,<has_many_video>video,gap,command:playlist_add:script-message snow-add-files?Add videos to playlist,playlist,space,prev,next,shuffle,loop-playlist,loop-file,speed,gap,fullscreen

# --- look: icon-only buttons (no box), round soft highlight on hover, slim timeline
controls_size=36
controls_margin=12
controls_spacing=6
border_radius=12
# button background box: 0 = icons only. For a dark pill behind every icon try:  opacity=controls=0.45,timeline=0.55
opacity=controls=0,timeline=0.55
timeline_style=bar
timeline_line_width=4
timeline_size=30
timeline_border=0
# no permanent progress line: the bar only shows when you move the mouse down or press Left/Right (flash_duration)
progress=never
progress_size=3
# time on the right side of the timeline = total length (other: playtime-remaining, time-remaining)
destination_time=total
top_bar=no-border
top_bar_size=38
menu_item_height=40
animation_duration=150
flash_duration=1500
font_scale=1
# colors (hex, no #): background = dark panels / pill, foreground = icons, timeline, text
color=foreground=ffffff,foreground_text=101014,background=101014,background_text=ffffff,curtain=000000
SNOW_EOF

echo "== 4/4 uosc interface"
if [ ! -f "$M/scripts/uosc/main.lua" ] || [ "${1:-}" = "--update" ]; then
  if command -v curl >/dev/null && command -v unzip >/dev/null; then
    T="$(mktemp -d)"
    if curl -fsSL --retry 2 -o "$T/uosc.zip" https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip </dev/null && unzip -qo "$T/uosc.zip" -d "$M"; then
      echo "uosc installed"
    else
      echo "WARN: uosc download failed (internet?). mpv still works with its normal controls. Run again later."
    fi
    rm -rf "$T"
  else
    echo "WARN: curl and unzip are needed to download uosc."
  fi
else
  echo "uosc already installed (use --update to refresh)"
fi
# our uosc settings go on top (the uosc download brings its own default file)
mv -f /tmp/snow-uosc.conf.$$ "$M/script-opts/uosc.conf"
echo
echo "DONE. Test:  mpv <video>   (Add videos button = bottom bar; keys are in ~/.config/mpv/input.conf)"
