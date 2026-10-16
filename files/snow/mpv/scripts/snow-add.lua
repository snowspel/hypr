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
