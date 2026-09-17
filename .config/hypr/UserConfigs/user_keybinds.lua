-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User keybind overrides (auto-generated).
-- Add, override, or rebind keybinds with bind("MODS", "KEY", fn, opts) and unbind("MODS", "KEY").
--
-- 1. ADDING A NEW KEYBIND (combo not used by default):
--    bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--    bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio Control" })
--
-- 2. OVERRIDING AN EXISTING COMBO WITH A DIFFERENT APP/COMMAND:
--    unbind("SUPER", "Return")
--    bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--
-- 3. REBINDING AN ACTION TO A NEW KEY COMBINATION:
--    unbind("SUPER", "E")
--    unbind("SUPER", "F")
--    bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"), { description = "File manager" })
--    bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
--
-- 4. REBINDING DISPATCHERS (e.g. killactive, workspace):
--    unbind("SUPER", "Q")
--    bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
--
-- 5. BIND OPTIONS (locked, repeating):
--    bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Brightness up", repeating = true })
--    bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Mute audio", locked = true })
--
-- Helper functions live in ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/user_keybinds_helper.lua so they can be updated separately.
local user_keybinds_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_keybinds_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.bind then
          user_keybinds_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local exec_cmd = user_keybinds_helper.exec_cmd
local dispatch = user_keybinds_helper.dispatch
local bind = user_keybinds_helper.bind
local unbind = user_keybinds_helper.unbind

-- =============================================================================
-- USER CUSTOM KEYBINDINGS
-- =============================================================================
-- Unbind default conflicting keybinds
unbind("SUPER", "D")
unbind("SUPER", "S")
unbind("SUPER", "Return")
unbind("SUPER", "Q")
unbind("CTRL ALT", "L")
unbind("SUPER ALT", "E")
unbind("SUPER SHIFT", "Q")
unbind("SUPER", "SPACE")
unbind("SUPER SHIFT", "S")
unbind("SUPER SHIFT", "Print")
unbind("SUPER", "left")
unbind("SUPER", "right")
unbind("SUPER", "up")
unbind("SUPER", "down")

-- App Launcher & Apps
bind("SUPER", "S", exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"), { description = "app launcher" })
bind("CTRL ALT", "B", exec_cmd("xdg-open 'https://'"), { description = "open default browser" })
bind("SUPER", "X", exec_cmd(""), { description = "Open terminal" })
bind("SUPER", "period", exec_cmd("/home/wray/.config/hypr/scripts/RofiEmoji.sh"), { description = "emoji menu" })

-- Window actions
bind("ALT", "SPACE", dispatch("togglefloating", ""), { description = "Float current window" })
bind("SUPER", "D", dispatch("killactive", ""), { description = "close active window" })
bind("SUPER", "ESCAPE", dispatch("killactive", ""), { description = "close active window" })
bind("ALT", "F4", exec_cmd("/home/wray/.config/hypr/scripts/KillActiveProcess.sh"), { description = "Terminate active process" })
bind("SUPER", "L", exec_cmd("/home/wray/.config/hypr/scripts/LockScreen.sh"), { description = "lock screen" })
bind("SUPER SHIFT", "S", exec_cmd("/home/wray/.config/hypr/scripts/ScreenShot.sh --area"), { description = "screenshot (area)" })

-- Move workspace to monitor
bind("SUPER SHIFT", "left", dispatch("movecurrentworkspacetomonitor", "l"), { description = "move workspace to left monitor" })
bind("SUPER SHIFT", "right", dispatch("movecurrentworkspacetomonitor", "r"), { description = "move workspace to right monitor" })
bind("SUPER SHIFT", "up", dispatch("movecurrentworkspacetomonitor", "u"), { description = "move workspace to up monitor" })
bind("SUPER SHIFT", "down", dispatch("movecurrentworkspacetomonitor", "d"), { description = "move workspace to down monitor" })

-- Move window
bind("SUPER", "left", dispatch("movewindow", "l"), { description = "move window left" })
bind("SUPER", "right", dispatch("movewindow", "r"), { description = "move window right" })
bind("SUPER", "up", dispatch("movewindow", "u"), { description = "move window up" })
bind("SUPER", "down", dispatch("movewindow", "d"), { description = "move window down" })

-- Focus window
bind("CTRL ALT", "left", dispatch("movefocus", "l"), { description = "focus left" })
bind("CTRL ALT", "right", dispatch("movefocus", "r"), { description = "focus right" })
bind("CTRL ALT", "up", dispatch("movefocus", "u"), { description = "focus up" })
bind("CTRL ALT", "down", dispatch("movefocus", "d"), { description = "focus down" })

-- Resize window
bind("SUPER ALT", "left", dispatch("resizeactive", "-50 0"), { description = "resize left", repeating = true })
bind("SUPER ALT", "right", dispatch("resizeactive", "50 0"), { description = "resize right", repeating = true })
bind("SUPER ALT", "up", dispatch("resizeactive", "0 -50"), { description = "resize up", repeating = true })
bind("SUPER ALT", "down", dispatch("resizeactive", "0 50"), { description = "resize down", repeating = true })

-- Move active window to workspace
for i = 1, 10 do
  local key = tostring(i % 10)
  bind("SUPER CTRL", key, dispatch("movetoworkspace", tostring(i)), { description = "move to workspace " .. i })
end

-- Custom toggle opacity
bind("SUPER", "T", exec_cmd("hyprctl getoption decoration:inactive_opacity | grep -q 'float: 0.9' && hyprctl --batch 'keyword decoration:active_opacity 1.2; keyword decoration:inactive_opacity 1.2' || hyprctl --batch 'keyword decoration:active_opacity 1.0; keyword decoration:inactive_opacity 0.9'"), { description = "toggle opacity" })
