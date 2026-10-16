------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------
local terminal    = "kitty"
local fileManager = "nautilus --new-window"
local browser     = "brave-origin"
local home        = os.getenv("HOME")
local snowPath    = home .. "/.config/quickshell/snow"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("bash " .. home .. "/.config/snow/bin/start-polkit.sh")
    hl.exec_cmd("qs -p " .. snowPath)
    hl.exec_cmd("bash " .. home .. "/.config/snow/bin/switch-theme.sh --restore")
    hl.exec_cmd("bash " .. home .. "/.config/snow/bin/power.sh start")   -- screen off / lock / sleep timers (hypridle)
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QS_ICON_THEME", "Papirus-Dark")
-- Show Flatpak apps in the launcher: add the flatpak exports to XDG_DATA_DIRS
hl.env("XDG_DATA_DIRS", (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share")
    .. ":/var/lib/flatpak/exports/share:" .. home .. "/.local/share/flatpak/exports/share")

-- NVIDIA (RTX 3060 Ti)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Gaps, border, rounding, shadow, blur, animations: ~/.config/hypr/look.lua (changed from the Themes menu)
local ok, err = pcall(dofile, home .. "/.config/hypr/look.lua")
if not ok then print("snow look.lua error: " .. tostring(err)) end

hl.config({
    general = {
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        key_press_enables_dpms   = true,   -- wake the screen with a key
        mouse_move_enables_dpms  = true,   -- ... or with the mouse
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        numlock_by_default = true,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("localsend"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("librewolf"))

-- Window control
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- Exit Hyprland
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- snow panels (Quickshell IPC)
local function snow(target)
    return hl.dsp.exec_cmd("qs -p " .. snowPath .. " ipc call " .. target .. " toggle")
end
hl.bind(mainMod .. " + SPACE",  snow("launcher"))
hl.bind(mainMod .. " + Escape", snow("power"))
hl.bind(mainMod .. " + Tab",    snow("control"))
hl.bind(mainMod .. " + BackSpace", snow("clock"))
hl.bind(mainMod .. " + A",      snow("themes"))

-- Focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse drag / resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume / media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Screenshot: full screen (Super+Shift+S)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd([[
mkdir -p "$HOME/Pictures/Screenshots"
f="$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"
grim "$f" && wl-copy --type image/png < "$f" && notify-send "Screenshot saved" "$f"
]]))

-- Screenshot: area select (Super+S)
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd([[
mkdir -p "$HOME/Pictures/Screenshots"
f="$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"
grim -g "$(slurp)" "$f" && wl-copy --type image/png < "$f" && notify-send "Screenshot saved" "$f"
]]))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Floating windows -----------------------------------------------------
-- Update / Clean terminals opened from Quick Settings (kitty --class snow-float): small, centered
hl.window_rule({ name = "snow-terminals", match = { class = "^snow-float$" }, float = true, center = true, size = "900 560" })
-- File pickers (Open / Save dialogs from the GTK portal) and the usual dialog titles
hl.window_rule({ name = "file-picker", match = { class = "^xdg-desktop-portal-gtk$" }, float = true, center = true, size = "900 600" })
hl.window_rule({ name = "file-dialog-titles", match = { title = "^(Open File|Open Files|Open Folder|Save As|Save File|Select Folder)$" }, float = true, center = true })
-- Volume control (pavucontrol)
hl.window_rule({ name = "volume-dialog", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" }, float = true, center = true, size = "800 600" })
-- Browser picture-in-picture: floating and always on top
hl.window_rule({ name = "pip", match = { title = "^[Pp]icture[ -][Ii]n[ -][Pp]icture$" }, float = true, pin = true })

-- Wallpaper picker (zenity file window)
hl.window_rule({ name = "wallpaper-picker", match = { class = "^zenity$" }, float = true, center = true, size = "900 600" })
