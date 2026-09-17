-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- System defaults migrated from configs/Keybinds.conf (auto-generated).
-- Add keybinds with bind("MODS", "KEY", fn, opts).
-- Example:
-- bind("SUPER", "Z", exec_cmd("thunar"), { description = "Open file manager" })

local dsp = hl.dsp or hl
local function resolve_cmd(cmd)
  local defaults = rawget(_G, "KOOLDOTS_DEFAULTS") or {}
  local resolved_term = defaults.term or os.getenv("TERMINAL") or "kitty"
  local resolved_files = defaults.files or "thunar"
  local resolved_edit = defaults.edit or os.getenv("EDITOR") or "nano"
  local resolved_visual = defaults.visual or os.getenv("VISUAL") or ""
  cmd = tostring(cmd)
  cmd = cmd:gsub("%$term", resolved_term)
  cmd = cmd:gsub("%$files", resolved_files)
  cmd = cmd:gsub("%$edit", resolved_edit)
  cmd = cmd:gsub("%$visual", resolved_visual)
  return cmd
end

local function exec_cmd(cmd)
  local resolved = resolve_cmd(cmd)
  if dsp and dsp.exec_cmd then
    return dsp.exec_cmd(resolved)
  end
  return function() hl.exec_cmd(resolved) end
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function raw_dispatch_cmd(command)
  if dsp and dsp.exec_raw then
    return dsp.exec_raw(tostring(command))
  end
  local expression = "hl.dsp.exec_raw(" .. string.format("%q", tostring(command)) .. ")"
  return exec_cmd("hyprctl dispatch " .. shell_quote(expression))
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize_mods(mods)
  mods = trim(mods)
  if mods == "" then
    return ""
  end
  local known = {
    super = "SUPER",
    super_l = "SUPER_L",
    super_r = "SUPER_R",
    shift = "SHIFT",
    shift_l = "SHIFT_L",
    shift_r = "SHIFT_R",
    ctrl = "CTRL",
    control = "CTRL",
    ctrl_l = "CTRL_L",
    ctrl_r = "CTRL_R",
    control_l = "CTRL_L",
    control_r = "CTRL_R",
    alt = "ALT",
    alt_l = "ALT_L",
    alt_r = "ALT_R",
    meta = "META",
    meta_l = "META_L",
    meta_r = "META_R",
    mod2 = "MOD2",
    mod3 = "MOD3",
    mod5 = "MOD5",
  }
  local parts = {}
  for token in mods:gmatch("%S+") do
    parts[#parts + 1] = known[token:lower()] or token
  end
  return table.concat(parts, " ")
end

local function chord(mods, key)
  mods = normalize_mods(mods):gsub("%s+", " + ")
  key = trim(key)
  if mods == "" then
    return key
  end
  return mods .. " + " .. key
end

local function key_variants(key, mods)
  key = trim(key):gsub("^xf86", "XF86")
  local key_aliases = {
    XF86AudioPlayPause = "XF86AudioPlay",
    XF86audiolowervolume = "XF86AudioLowerVolume",
    XF86audiomute = "XF86AudioMute",
    XF86audioraisevolume = "XF86AudioRaiseVolume",
    XF86audiostop = "XF86AudioStop",
  }
  key = key_aliases[key] or key
  local shifted_number_keys = {
    ["code:10"] = "exclam",
    ["code:11"] = "at",
    ["code:12"] = "numbersign",
    ["code:13"] = "dollar",
    ["code:14"] = "percent",
    ["code:15"] = "asciicircum",
    ["code:16"] = "ampersand",
    ["code:17"] = "asterisk",
    ["code:18"] = "parenleft",
    ["code:19"] = "parenright",
  }
  local number_keys = {
    ["code:10"] = "1",
    ["code:11"] = "2",
    ["code:12"] = "3",
    ["code:13"] = "4",
    ["code:14"] = "5",
    ["code:15"] = "6",
    ["code:16"] = "7",
    ["code:17"] = "8",
    ["code:18"] = "9",
    ["code:19"] = "0",
  }
  if mods:upper():match("SHIFT") and shifted_number_keys[key] then
    local number_key = number_keys[key]
    if number_key then
      return { shifted_number_keys[key], number_key }
    end
    return { shifted_number_keys[key] }
  end
  if number_keys[key] then
    return { number_keys[key] }
  end
  return { key }
end

local function workspace_value(value)
  value = trim(value)
  return tonumber(value) or value
end

local function direction(value)
  local directions = {
    l = "left",
    r = "right",
    u = "up",
    d = "down",
    left = "left",
    right = "right",
    up = "up",
    down = "down",
  }
  return directions[trim(value)] or trim(value)
end

local function dispatch(name, args)
  local window_api = (dsp and dsp.window) or hl.window or {}
  name = trim(name)
  args = trim(args)
  if name == "exec" then
    return exec_cmd(args)
  end
  if name == "killactive" and window_api.close then
    return window_api.close()
  end
  if name == "fullscreen" and window_api.fullscreen then
    if args == "1" then
      return window_api.fullscreen({ mode = "maximized" })
    end
    return window_api.fullscreen({ mode = "fullscreen" })
  end
  if name == "movefocus" and dsp and dsp.focus then
    return function()
      local ok, dispatcher = pcall(dsp.focus, { direction = direction(args) })
      if ok and dispatcher then
        hl.dispatch(dispatcher)
      end
    end
  end
  if name == "cyclenext" then
    if args == "prev" or args == "b" then
      return exec_cmd("${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/LuaCycleWindow.sh previous")
    end
    return exec_cmd("${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/LuaCycleWindow.sh next")
  end
  if name == "swapwindow" then
    local swap_direction = trim(args)
    if swap_direction == "" then
      return nil
    end
    return exec_cmd("${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/LuaSwapWindow.sh " .. swap_direction)
  end
  if name == "workspace" and dsp and dsp.focus then
    return function() hl.dispatch(dsp.focus({ workspace = workspace_value(args) })) end
  end
  if name == "movetoworkspace" and window_api.move then
    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args) })) end
  end
  if name == "movetoworkspacesilent" and window_api.move then
    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false })) end
  end
  if name == "togglefloating" and window_api.float then
    return function() hl.dispatch(window_api.float({ action = "toggle" })) end
  end
  if name == "resizewindow" and window_api.resize then
    return window_api.resize()
  end
  if name == "resizeactive" and window_api.resize then
    local x, y = args:match("^(%-?%d+)%s+(%-?%d+)$")
    if x and y then
      return window_api.resize({ x = tonumber(x) or 0, y = tonumber(y) or 0, relative = true })
    end
  end
  if name == "movewindow" and args == "" and window_api.drag then
    return window_api.drag()
  end
  if args ~= "" then
    return raw_dispatch_cmd(name .. " " .. args)
  end
  return raw_dispatch_cmd(name)
end

local function bind(mods, key, fn, opts)
  local seen = {}
  for _, key_variant in ipairs(key_variants(key, mods)) do
    local key_chord = chord(mods, key_variant)
    if not seen[key_chord] then
      seen[key_chord] = true
      if opts then
        hl.bind(key_chord, fn, opts)
      else
        hl.bind(key_chord, fn)
      end
    end
  end
end

local function unbind(mods, key)
  if hl.unbind then
    local seen = {}
    for _, key_variant in ipairs(key_variants(key, mods)) do
      local key_chord = chord(mods, key_variant)
      if not seen[key_chord] then
        seen[key_chord] = true
        local ok = pcall(hl.unbind, mods, key_variant)
        if not ok then
          pcall(hl.unbind, key_chord)
        end
      end
    end
  end
end

-- Converted from configs/Keybinds.conf
bind("SUPER", "S", exec_cmd("pkill rofi || true && rofi -show drun -modi drun, filebrowser, run, window"), { description = "app launcher" })
bind("CTRL ALT", "B", exec_cmd("xdg-open \"https://\""), { description = "open default browser" })
bind("SUPER", "A", exec_cmd("$HOME/.config/hypr/scripts/OverviewToggle.sh"), { description = "desktop overview" })
bind("SUPER", "X", exec_cmd("$term"), { description = "Open terminal" })
bind("SUPER", "E", exec_cmd("$files"), { description = "file manager" })
bind("SUPER", "H", exec_cmd("$HOME/.config/hypr/scripts/KeyHints.sh"), { description = "help / cheat sheet" })
bind("SUPER ALT", "R", exec_cmd("$HOME/.config/hypr/scripts/Refresh.sh"), { description = "refresh bar and menus" })
bind("SUPER", "period", exec_cmd("$HOME/.config/hypr/scripts/RofiEmoji.sh"), { description = "emoji menu" })
bind("SUPER CTRL", "S", exec_cmd("rofi -show window"), { description = "window switcher" })
bind("SUPER ALT", "O", exec_cmd("$HOME/.config/hypr/scripts/ChangeBlur.sh"), { description = "toggle blur" })
bind("SUPER SHIFT", "G", exec_cmd("$HOME/.config/hypr/scripts/GameMode.sh"), { description = "toggle game mode" })
bind("SUPER ALT", "L", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh"), { description = "toggle master/dwindle layout" })
bind("SUPER ALT", "V", exec_cmd("$HOME/.config/hypr/scripts/ClipManager.sh"), { description = "clipboard manager" })
bind("SUPER CTRL", "R", exec_cmd("$HOME/.config/hypr/scripts/RofiThemeSelector.sh"), { description = "rofi theme selector" })
bind("SUPER CTRL SHIFT", "R", exec_cmd("pkill rofi || true && $HOME/.config/hypr/scripts/RofiThemeSelector-modified.sh"), { description = "rofi theme selector (modified)" })
bind("SUPER SHIFT", "F", dispatch("fullscreen", ""), { description = "fullscreen" })
bind("SUPER CTRL", "F", dispatch("fullscreen", "1"), { description = "maximize window" })
bind("ALT", "SPACE", dispatch("togglefloating", ""), { description = "Float current window" })
bind("SUPER ALT", "SPACE", exec_cmd("hyprctl dispatch workspaceopt allfloat"), { description = "Float all windows" })
bind("SUPER SHIFT", "Return", exec_cmd("$HOME/.config/hypr/scripts/Dropterminal.sh $term"), { description = "DropDown terminal" })
bind("SUPER ALT", "mouse_down", exec_cmd("hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')\""), { description = "zoom in" })
bind("SUPER ALT", "mouse_up", exec_cmd("hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')\""), { description = "zoom out" })
bind("SUPER CTRL ALT", "B", exec_cmd("pkill -SIGUSR1 waybar"), { description = "toggle waybar on/off" })
bind("SUPER CTRL", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarStyles.sh"), { description = "waybar styles menu" })
bind("SUPER ALT", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarLayout.sh"), { description = "waybar layout menu" })
bind("SUPER", "N", exec_cmd("$HOME/.config/hypr/scripts/Hyprsunset.sh toggle"), { description = "toggle night light" })
bind("SUPER SHIFT", "M", exec_cmd("$HOME/.config/hypr/UserScripts/RofiBeats.sh"), { description = "online music" })
bind("SUPER", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"), { description = "select wallpaper" })
bind("SUPER SHIFT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperEffects.sh"), { description = "wallpaper effects" })
bind("CTRL ALT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperRandom.sh"), { description = "random wallpaper" })
bind("SUPER CTRL", "O", exec_cmd("hyprctl setprop active opaque toggle"), { description = "toggle active window opacity" })
bind("SUPER SHIFT", "K", exec_cmd("$HOME/.config/hypr/scripts/KeyBinds.sh"), { description = "search keybinds" })
bind("SUPER SHIFT", "A", exec_cmd("$HOME/.config/hypr/scripts/Animations.sh"), { description = "animations menu" })
bind("SUPER SHIFT", "O", exec_cmd("$HOME/.config/hypr/UserScripts/ZshChangeTheme.sh"), { description = "change oh-my-zsh theme" })
bind("ALT", "SHIFT_L", exec_cmd("$HOME/.config/hypr/scripts/SwitchKeyboardLayout.sh"), { description = "switch keyboard layout globally", locked = true })
bind("SHIFT", "ALT_L", exec_cmd("$HOME/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"), { description = "switch keyboard layout per-window", locked = true })
bind("SUPER ALT", "C", exec_cmd("$HOME/.config/hypr/UserScripts/RofiCalc.sh"), { description = "calculator" })
bind("SUPER SHIFT", "left", dispatch("movecurrentworkspacetomonitor", "l"), { description = "move workspace to left monitor" })
bind("SUPER SHIFT", "right", dispatch("movecurrentworkspacetomonitor", "r"), { description = "move workspace to right monitor" })
bind("SUPER SHIFT", "up", dispatch("movecurrentworkspacetomonitor", "u"), { description = "move workspace to up monitor" })
bind("SUPER SHIFT", "down", dispatch("movecurrentworkspacetomonitor", "d"), { description = "move workspace to down monitor" })
bind("CTRL ALT", "Delete", exec_cmd("hyprctl dispatch exit 0"), { description = "exit Hyprland" })
bind("SUPER", "D", dispatch("killactive", ""), { description = "close active window" })
bind("SUPER", "ESCAPE", dispatch("killactive", ""), { description = "close active window" })
bind("ALT", "F4", exec_cmd("$HOME/.config/hypr/scripts/KillActiveProcess.sh"), { description = "Terminate active process" })
bind("SUPER", "L", exec_cmd("$HOME/.config/hypr/scripts/LockScreen.sh"), { description = "lock screen" })
bind("CTRL ALT", "P", exec_cmd("$HOME/.config/hypr/scripts/Wlogout.sh"), { description = "powermenu" })
bind("SUPER SHIFT", "N", exec_cmd("swaync-client -t -sw"), { description = "notification panel" })
bind("SUPER SHIFT", "E", exec_cmd("$HOME/.config/hypr/scripts/Kool_Quick_Settings.sh"), { description = "Quick settings menu" })
bind("SUPER CTRL", "D", dispatch("layoutmsg", "removemaster"), { description = "remove master" })
bind("SUPER", "I", dispatch("layoutmsg", "addmaster"), { description = "add master" })
bind("SUPER CTRL", "Return", dispatch("layoutmsg", "swapwithmaster"), { description = "swap with master" })
bind("SUPER SHIFT", "I", dispatch("layoutmsg", "togglesplit"), { description = "toggle split (dwindle)" })
bind("SUPER", "P", dispatch("layoutmsg", "pseudo"), { description = "toggle pseudo (dwindle)" })
bind("SUPER", "M", exec_cmd("hyprctl dispatch splitratio 0.3"), { description = "set split ratio 0.3" })
bind("ALT", "tab", dispatch("cyclenext", ""), { description = "cycle next window" })
bind("ALT", "tab", dispatch("bringactivetotop", ""), { description = "bring active to top" })
bind("", "xf86audioraisevolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc"), { description = "volume up", locked = true, ["repeat"] = true })
bind("", "xf86audiolowervolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --dec"), { description = "volume down", locked = true, ["repeat"] = true })
bind("", "xf86AudioMicMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle-mic"), { description = "toggle mic mute", locked = true })
bind("", "xf86audiomute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "toggle mute", locked = true })
bind("", "xf86Sleep", exec_cmd("systemctl suspend"), { description = "sleep", locked = true })
bind("", "xf86Rfkill", exec_cmd("$HOME/.config/hypr/scripts/AirplaneMode.sh"), { description = "airplane mode", locked = true })
bind("", "xf86AudioPlayPause", exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --pause"), { description = "play/pause", locked = true })
bind("", "xf86AudioPause", exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --pause"), { description = "pause", locked = true })
bind("", "xf86AudioPlay", exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --pause"), { description = "play", locked = true })
bind("", "xf86AudioNext", exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --nxt"), { description = "next track", locked = true })
bind("", "xf86AudioPrev", exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --prv"), { description = "previous track", locked = true })
bind("", "xf86audiostop", exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --stop"), { description = "stop", locked = true })
bind("SUPER", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --now"), { description = "screenshot now" })
bind("SUPER SHIFT", "S", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --area"), { description = "screenshot (area)" })
bind("SUPER ALT", "left", dispatch("resizeactive", "-50 0"), { description = "resize left (-50)", ["repeat"] = true })
bind("SUPER ALT", "right", dispatch("resizeactive", "50 0"), { description = "resize right (+50)", ["repeat"] = true })
bind("SUPER ALT", "up", dispatch("resizeactive", "0 -50"), { description = "resize up (-50)", ["repeat"] = true })
bind("SUPER ALT", "down", dispatch("resizeactive", "0 50"), { description = "resize down (+50)", ["repeat"] = true })
bind("SUPER", "left", dispatch("movewindow", "l"), { description = "move window left" })
bind("SUPER", "right", dispatch("movewindow", "r"), { description = "move window right" })
bind("SUPER", "up", dispatch("movewindow", "u"), { description = "move window up" })
bind("SUPER", "down", dispatch("movewindow", "d"), { description = "move window down" })
bind("SUPER", "G", dispatch("togglegroup", ""), { description = "toggle group" })
bind("SUPER", "Tab", dispatch("changegroupactive", "f"), { description = "Change Group Forward" })
bind("SUPER CTRL", "tab", dispatch("changegroupactive", ""), { description = "change active in group" })
bind("SUPER SHIFT", "Tab", dispatch("changegroupactive", "b"), { description = "Change Group Back" })
bind("SUPER CTRL", "K", dispatch("moveintogroup", "l"), { description = "Move left into group" })
bind("SUPER CTRL", "L", dispatch("moveintogroup", "r"), { description = "Move Right into group" })
bind("SUPER CTRL", "H", dispatch("moveoutofgroup", ""), { description = "Move active out of group" })
bind("CTRL ALT", "left", dispatch("movefocus", "l"), { description = "focus left" })
bind("CTRL ALT", "right", dispatch("movefocus", "r"), { description = "focus right" })
bind("CTRL ALT", "up", dispatch("movefocus", "u"), { description = "focus up" })
bind("CTRL ALT", "down", dispatch("movefocus", "d"), { description = "focus down" })
bind("SUPER", "tab", dispatch("workspace", "m+1"), { description = "next workspace" })
bind("SUPER SHIFT", "tab", dispatch("workspace", "m-1"), { description = "previous workspace" })
bind("SUPER SHIFT", "U", dispatch("movetoworkspace", "special"), { description = "move to special workspace" })
bind("SUPER", "U", dispatch("togglespecialworkspace", ""), { description = "toggle special workspace" })
bind("SUPER", "code:10", dispatch("workspace", "1"), { description = "workspace 1" })
bind("SUPER", "code:11", dispatch("workspace", "2"), { description = "workspace 2" })
bind("SUPER", "code:12", dispatch("workspace", "3"), { description = "workspace 3" })
bind("SUPER", "code:13", dispatch("workspace", "4"), { description = "workspace 4" })
bind("SUPER", "code:14", dispatch("workspace", "5"), { description = "workspace 5" })
bind("SUPER", "code:15", dispatch("workspace", "6"), { description = "workspace 6" })
bind("SUPER", "code:16", dispatch("workspace", "7"), { description = "workspace 7" })
bind("SUPER", "code:17", dispatch("workspace", "8"), { description = "workspace 8" })
bind("SUPER", "code:18", dispatch("workspace", "9"), { description = "workspace 9" })
bind("SUPER", "code:19", dispatch("workspace", "10"), { description = "workspace 10" })
bind("SUPER CTRL", "code:10", dispatch("movetoworkspace", "1"), { description = "move to workspace 1" })
bind("SUPER CTRL", "code:11", dispatch("movetoworkspace", "2"), { description = "move to workspace 2" })
bind("SUPER CTRL", "code:12", dispatch("movetoworkspace", "3"), { description = "move to workspace 3" })
bind("SUPER CTRL", "code:13", dispatch("movetoworkspace", "4"), { description = "move to workspace 4" })
bind("SUPER CTRL", "code:14", dispatch("movetoworkspace", "5"), { description = "move to workspace 5" })
bind("SUPER CTRL", "code:15", dispatch("movetoworkspace", "6"), { description = "move to workspace 6" })
bind("SUPER CTRL", "code:16", dispatch("movetoworkspace", "7"), { description = "move to workspace 7" })
bind("SUPER CTRL", "code:17", dispatch("movetoworkspace", "8"), { description = "move to workspace 8" })
bind("SUPER CTRL", "code:18", dispatch("movetoworkspace", "9"), { description = "move to workspace 9" })
bind("SUPER CTRL", "code:19", dispatch("movetoworkspace", "10"), { description = "move to workspace 10" })
bind("SUPER CTRL", "bracketleft", dispatch("movetoworkspace", "-1"), { description = "move to previous workspace" })
bind("SUPER CTRL", "bracketright", dispatch("movetoworkspace", "+1"), { description = "move to next workspace" })
bind("SUPER", "mouse_down", dispatch("workspace", "e+1"), { description = "next workspace" })
bind("SUPER", "mouse_up", dispatch("workspace", "e-1"), { description = "previous workspace" })
bind("SUPER", "mouse:272", dispatch("movewindow", ""), { description = "move window" })
bind("SUPER", "mouse:273", dispatch("resizewindow", ""), { description = "resize window" })
bind("SUPER", "T", exec_cmd("hyprctl getoption decoration:inactive_opacity | grep -q \"float: 0.9\" && hyprctl --batch \"keyword decoration:active_opacity 1.2; keyword decoration:inactive_opacity 1.2\" || hyprctl --batch \"keyword decoration:active_opacity 1.0; keyword decoration:inactive_opacity 0.9\""))
bind("", "xf86KbdBrightnessDown", exec_cmd("$HOME/.config/hypr/scripts/BrightnessKbd.sh --dec"), { ["repeat"] = true })
bind("", "xf86KbdBrightnessUp", exec_cmd("$HOME/.config/hypr/scripts/BrightnessKbd.sh --inc"), { ["repeat"] = true })
bind("", "xf86Launch1", exec_cmd("rog-control-center"))
bind("", "xf86Launch3", exec_cmd("asusctl led-mode -n"))
bind("", "xf86Launch4", exec_cmd("asusctl profile -n"))
bind("", "xf86MonBrightnessDown", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --dec"), { ["repeat"] = true })
bind("", "xf86MonBrightnessUp", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { ["repeat"] = true })
bind("", "xf86TouchpadToggle", exec_cmd("$HOME/.config/hypr/scripts/TouchPad.sh"))
bind("SUPER", "F6", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --now"))
bind("SUPER SHIFT", "F6", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --area"))
bind("SUPER CTRL", "F6", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --in5"))
bind("SUPER ALT", "F6", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --in10"))
bind("ALT", "F6", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --active"))
