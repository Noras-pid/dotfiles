-- Orrery with the existing keyboard shortcuts and Rei wallpaper.
local home = os.getenv("HOME")
-- User commands must be visible to both Hyprland and the desktop shell.
local bin = home .. "/.local/bin"
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then path = bin .. ":" .. path end
hl.env("PATH", path)
package.path = package.path .. ";" .. home .. "/.config/caelestia/?.lua"
local vars = require("variables")
local overrides = dofile(home .. "/.config/caelestia/hypr-vars.lua")
if type(overrides) == "table" then
    for key, value in pairs(overrides) do vars[key] = value end
end

-- Read the same defaults that Menu > Default apps writes.
local function available(cmd)
    local p = io.popen("command -v '" .. cmd:gsub("'", "'\"'\"'") .. "' 2>/dev/null")
    local found = p and p:read("*l")
    if p then p:close() end
    return found and found ~= ""
end
for _, kind in ipairs({ "terminal", "browser" }) do
    local f = io.open(home .. "/.config/orrery/defaults/" .. kind)
    if f then
        local cmd = f:read("*l"); f:close()
        if cmd and cmd:match("^[%w_.+-]+$") and available(cmd) then vars[kind] = cmd end
    end
end
if not available(vars.editor) then
    local editor = available("micro") and "micro" or "nano"
    vars.editor = vars.terminal .. " -e " .. editor
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
require("hyprland.env")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.group")
require("hyprland.gestures")
require("hyprland.rules")
require("rei_execs")

-- Orrery window proportions, with blur disabled for the integrated GPU.
dofile(home .. "/.config/hypr/modules/decorations.lua")
dofile(home .. "/.config/orrery/current/hyprland.lua")
hl.config({
    general = { gaps_in = 6, gaps_out = 12, border_size = 1 },
    decoration = {
        rounding = 8,
        active_opacity = 1,
        inactive_opacity = 1,
        blur = { enabled = false },
        shadow = { enabled = true, range = 4, render_power = 2 },
    },
})
-- The floating bar sits 12px from the screen sides (Bar.qml sideGap); keep windows on the same edge.
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 12 })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 12 })
-- Rei motion: springs for whatever moves (they settle like real objects), short
-- curves for whatever only appears or leaves. Bounce: zeta = dampening / (2 * sqrt(stiffness)).
hl.curve("reiEase",  { type = "bezier", points = { { 0.22, 0.8 }, { 0.24, 1 } } })
hl.curve("reiOut",   { type = "bezier", points = { { 0.4, 0 }, { 1, 0.6 } } })
hl.curve("reiPop",   { type = "spring", mass = 1, stiffness = 320, dampening = 36 })   -- zeta 1.0: fast, stops dead, no bounce
hl.curve("reiGlide", { type = "spring", mass = 1, stiffness = 230, dampening = 31 })   -- zeta 1.0: no overshoot
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4.5, spring = "reiPop",   style = "popin 82%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4.5, spring = "reiGlide" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 1.6, bezier = "reiOut",   style = "popin 90%" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 1.8, bezier = "reiEase" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 1.4, bezier = "reiOut" })
hl.animation({ leaf = "fadeSwitch",       enabled = false })
hl.animation({ leaf = "border",           enabled = false })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4.5, spring = "reiGlide", style = "slide" })
hl.animation({ leaf = "workspacesIn",     enabled = true, speed = 4.5, spring = "reiGlide", style = "slide" })
hl.animation({ leaf = "workspacesOut",    enabled = true, speed = 4.5, spring = "reiGlide", style = "slide" })
-- overlays (launcher, menu, clipboard) land without the stock overshoot
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3.2, bezier = "orreryIn",  style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,   spring = "reiGlide", style = "slidevert" })

-- Games: Steam titles may tear instead of waiting for vsync (lower input lag);
-- the NVIDIA shader cache keeps 10 GB so compiled shaders aren't thrown away.
hl.config({ general = { allow_tearing = true } })
hl.window_rule({ name = "games-immediate", match = { class = "^steam_app_.*$" }, immediate = true })
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "10737418240")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")

-- Start the Orrery shell on the next Hyprland login.
hl.env("ORRERY_SHELL", "quickshell")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.config/hypr/scripts/shell.sh start")
end)

require("rei_keybinds_orrery")
require("rei_user")

-- Apply machine settings last, after the Rei defaults.
for _, name in ipairs({ "look.local.lua", "monitors.local.lua" }) do
    local path = home .. "/.config/hypr/modules/" .. name
    local f = io.open(path)
    if f then f:close(); dofile(path) end
end
