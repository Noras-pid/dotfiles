-- Original key combinations from Caelestia, with Orrery actions.
local vars = require("variables")
local fn   = require("utils.functions")
local keybind_rows = {}
local function key_label(key)
    for name, value in pairs(vars) do
        if name:sub(1, 2) == "kb" then
            local keys = type(value) == "table" and value or { value }
            for _, candidate in ipairs(keys) do
                if candidate == key then
                    return name:sub(3):gsub("(%l)(%u)", "%1 %2")
                end
            end
        end
    end
    return ({ ["SUPER + Space"] = "Menu", ["SUPER + ALT + G"] = "Game mode" })[key] or "Window / workspace action"
end


-- Flags
local locked           = { locked = true }
local mouse            = { mouse = true }
local release          = { release = true }
local repeating        = { repeating = true }
local locked_repeating = { locked = true, repeating = true }

local function normalise_keybind(key)
    return key:gsub("%s+", ""):lower()
end

local function valid_keybind(key)
    return type(key) == "string" and key:match("%S") ~= nil
end

local function repeating_unless_mouse(key)
    return not normalise_keybind(key):find("mouse", 1, true) and repeating or nil
end

local function flatten_keybinds(keybinds, keys)
    keys = keys or {}

    if type(keybinds) == "table" then
        for _, keybind in pairs(keybinds) do
            flatten_keybinds(keybind, keys)
        end
    elseif valid_keybind(keybinds) then
        keys[#keys + 1] = keybinds
    end

    return keys
end

local function create_bind(keybinds, action, flags, label)
    local get_flags = type(flags) == "function" and flags or function()
        return flags
    end

    for _, key in ipairs(flatten_keybinds(keybinds)) do
        hl.bind(key, action, get_flags(key))
        keybind_rows[#keybind_rows + 1] = {
            id = key, label = label or key_label(key), value = key:gsub("%s*%+%s*", "+"),
            description = "Active Hyprland binding", icon = "keyboard"
        }
    end
end

local function extend_keybind(base, suffix)
    return valid_keybind(base) and base .. " + " .. suffix or nil
end

-- Launcher
local launcher_default = normalise_keybind("SUPER + SUPER_L")
create_bind(
    vars.kbLauncher,
    hl.dsp.exec_cmd("qs ipc call launcher toggle"),
    function(key)
        return normalise_keybind(key) == launcher_default and release or nil
    end
)

-- Misc
create_bind(vars.kbSession, hl.dsp.exec_cmd("qs ipc call powermenu toggle"))
create_bind("SUPER + Space", hl.dsp.exec_cmd("qs ipc call menu toggle"))
create_bind(vars.kbShowSidebar, hl.dsp.exec_cmd("qs ipc call menu toggle"))
create_bind(vars.kbClearNotifs, hl.dsp.exec_cmd("qs ipc call notifications clear"), locked)
create_bind(vars.kbShowPanels, hl.dsp.exec_cmd("qs ipc call bar visible"))
create_bind(vars.kbLock, hl.dsp.exec_cmd("pidof hyprlock >/dev/null || hyprlock"))

-- Restore lock
create_bind(vars.kbRestoreLock, function()
    hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/scripts/shell.sh start"))
    hl.dispatch(hl.dsp.exec_cmd("pidof hyprlock >/dev/null || hyprlock"))
end)

-- Kill/restart
create_bind("CTRL + SUPER + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/shell.sh stop"), release)
create_bind(
    "CTRL + SUPER + ALT + R",
    hl.dsp.exec_cmd("~/.config/hypr/scripts/shell.sh restart"),
    release
)

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    create_bind(extend_keybind(vars.kbGoToWs, key), fn.wsaction("focus", "", i), nil, "Switch to workspace " .. i)
    create_bind(extend_keybind(vars.kbMoveWinToWs, key), fn.wsaction("move", "", i), nil, "Move window to workspace " .. i)
    create_bind(extend_keybind(vars.kbGoToWsGroup, key), fn.wsaction("focus", "group", i), nil, "Switch to workspace group " .. i)
    create_bind(extend_keybind(vars.kbMoveWinToWsGroup, key), fn.wsaction("move", "group", i), nil, "Move window to workspace group " .. i)
end

-- Go to workspace -1/+1
create_bind(vars.kbPrevWs, hl.dsp.focus({ workspace = "-1" }), repeating_unless_mouse)
create_bind(vars.kbNextWs, hl.dsp.focus({ workspace = "+1" }), repeating_unless_mouse)

-- Go to workspace group -1/+1
create_bind(vars.kbPrevWsGroup, hl.dsp.focus({ workspace = "-10" }), repeating_unless_mouse)
create_bind(vars.kbNextWsGroup, hl.dsp.focus({ workspace = "+10" }), repeating_unless_mouse)

-- Move window to workspace -1/+1
create_bind(vars.kbMoveWinToWsNext, hl.dsp.window.move({ workspace = "+1" }), repeating_unless_mouse)
create_bind(vars.kbMoveWinToWsPrev, hl.dsp.window.move({ workspace = "-1" }), repeating_unless_mouse)

-- Move window to/from special workspace
create_bind(vars.kbMoveWinToWsSpecial, hl.dsp.window.move({ workspace = "special:special" }))
create_bind(vars.kbMoveWinFromWsSpecial, hl.dsp.window.move({ workspace = "e+0" }))

-- Window groups
create_bind(vars.kbWindowCycleNext, hl.dsp.window.cycle_next(), repeating)
create_bind(vars.kbWindowCyclePrev, hl.dsp.window.cycle_next({ next = false }), repeating)
create_bind(vars.kbWindowGroupCycleNext, hl.dsp.group.next(), repeating)
create_bind(vars.kbWindowGroupCyclePrev, hl.dsp.group.prev(), repeating)
create_bind(vars.kbToggleGroup, hl.dsp.group.toggle())
create_bind(vars.kbUngroup, hl.dsp.window.move({ out_of_group = true }))
create_bind(vars.kbGroupLockActive, hl.dsp.group.lock_active())

-- Window actions
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    create_bind("SUPER + " .. dir, hl.dsp.focus({ direction = dir }))
    create_bind("SUPER + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

create_bind(vars.kbWindowDecreaseWidth, fn.resize_active_window(-10, 0), repeating)
create_bind(vars.kbWindowIncreaseWidth, fn.resize_active_window(10, 0), repeating)
create_bind(vars.kbWindowDecreaseHeight, fn.resize_active_window(0, -10), repeating)
create_bind(vars.kbWindowIncreaseHeight, fn.resize_active_window(0, 10), repeating)

create_bind({ vars.kbMoveWindow, "SUPER + mouse:272" }, hl.dsp.window.drag(), mouse)
create_bind({ vars.kbResizeWindow, "SUPER + mouse:273" }, hl.dsp.window.resize(), mouse)
create_bind(vars.kbCenterWindow, hl.dsp.window.center())
create_bind(vars.kbNormalizeWindow, function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_by_screen(55, 70)))
    hl.dispatch(hl.dsp.window.center())
end)
create_bind(vars.kbWindowPip, function()
    local a = hl.get_active_window()
    if a then
        local pip = fn.move_actions(a) or {}
        if not a.floating then table.insert(pip, 1, hl.dsp.window.float()) end
        table.insert(pip, hl.dsp.window.pin({ action = "on", window = "address:" .. a.address }))

        for _, x in ipairs(pip) do
            hl.dispatch(x)
        end
    end
end)
create_bind(vars.kbPinWindow, hl.dsp.window.pin())
create_bind(vars.kbWindowFullscreen, hl.dsp.window.fullscreen({ mode = "fullscreen" }))
create_bind(vars.kbWindowBorderedFullscreen, hl.dsp.window.fullscreen({ mode = "maximized" }))
create_bind(vars.kbToggleWindowFloating, hl.dsp.window.float())
create_bind(vars.kbCloseWindow, hl.dsp.window.close())

-- Special workspace toggles
create_bind(vars.kbSpecialWs, fn.toggle("specialws"))
create_bind(vars.kbSystemMonitorWs, fn.toggle("sysmon"))
create_bind(vars.kbMusicWs, fn.toggle("music"))
create_bind(vars.kbCommunicationWs, fn.toggle("communication"))
-- Only register application workspaces when their application exists.
local todo = io.popen("command -v todoist 2>/dev/null")
local todo_available = todo and todo:read("*l")
if todo then todo:close() end
if todo_available then create_bind(vars.kbTodoWs, fn.toggle("todo")) end

-- Apps
create_bind(vars.kbTerminal, hl.dsp.exec_cmd("uwsm app -- " .. vars.terminal))
create_bind(vars.kbBrowser, hl.dsp.exec_cmd("uwsm app -- " .. vars.browser))
create_bind(vars.kbEditor, hl.dsp.exec_cmd("uwsm app -- " .. vars.editor))
create_bind(vars.kbFileExplorer, hl.dsp.exec_cmd("uwsm app -- " .. vars.fileExplorer))
create_bind(vars.kbAudioSettings, hl.dsp.exec_cmd("uwsm app -- " .. vars.audioSettings))

-- Utilities
create_bind(vars.kbScreenshot, hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh screen"), locked)
create_bind(vars.kbScreenshotFreeze, hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))
create_bind(vars.kbScreenshotRegion, hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh edit"))
create_bind(vars.kbRecord, hl.dsp.exec_cmd("~/.local/bin/orrery-record toggle screen"))
create_bind(vars.kbRecordSound, hl.dsp.exec_cmd("~/.local/bin/orrery-record toggle sound"))
create_bind(vars.kbRecordRegion, hl.dsp.exec_cmd("~/.local/bin/orrery-record toggle region"))
create_bind(vars.kbColorPicker, hl.dsp.exec_cmd("hyprpicker -a"))

-- Brightness
create_bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), locked)
create_bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), locked)

-- Media
create_bind({ vars.kbMediaToggle, "XF86AudioPlay", "XF86AudioPause" }, hl.dsp.exec_cmd("playerctl play-pause"), locked)
create_bind({ vars.kbMediaNext, "XF86AudioNext" }, hl.dsp.exec_cmd("playerctl next"), locked)
create_bind({ vars.kbMediaPrev, "XF86AudioPrev" }, hl.dsp.exec_cmd("playerctl previous"), locked)
create_bind({ vars.kbMediaStop, "XF86AudioStop" }, hl.dsp.exec_cmd("playerctl stop"), locked)

-- Volume
create_bind({ vars.kbVolumeMute, "XF86AudioMute" }, hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked)
create_bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)
create_bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l " ..
        (vars.volumeMax / 100) .. " @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%+"
    ),
    locked_repeating
)
create_bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%-"
    ),
    locked_repeating
)

-- Sleep
create_bind(vars.kbSleep, hl.dsp.exec_cmd(vars.sleepGestureCmd), locked)

-- Clipboard and emoji picker
create_bind(vars.kbClipboard, hl.dsp.exec_cmd("qs ipc call clipboard toggle"))
create_bind(vars.kbClipboardDel, hl.dsp.exec_cmd("qs ipc call clipboard toggle"))
create_bind(vars.kbEmoji, hl.dsp.exec_cmd("~/.local/bin/orrery-emoji"))
create_bind(
    vars.kbClipboardPasteLatest,
    hl.dsp.exec_cmd("~/.local/bin/orrery-paste-latest"),
    locked
)

-- Testing
create_bind(
    "SUPER + ALT + F12",
    hl.dsp.exec_cmd(
        "notify-send -u low -i dialog-information-symbolic 'Test notification' " ..
        [["Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!"]] ..
        " -a 'Shell' -A 'Test1=I got it!' -A 'Test2=Another action'"
    )
)

-- The menu reads the actual bindings, rather than another rice's defaults.
keybind_rows[#keybind_rows + 1] = { id = "SUPER + ALT + G", label = "Game mode", value = "SUPER+ALT+G", icon = "keyboard" }
local keyfile = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/orrery-keybindings.json", "w")
if keyfile then
    keyfile:write(require("utils.json").encode(keybind_rows))
    keyfile:close()
end
