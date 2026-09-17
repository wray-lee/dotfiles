-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User decorations overrides (auto-generated).
-- This file is intentionally split from other user overrides.
-- Add only user-specific Lua overrides here.
-- Reads active border/shadow colors from wallust-hyprland.conf.

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local wallust_colors_file = config_home .. "/hypr/wallust/wallust-hyprland.conf"

local user_decorations_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_decorations_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_decorations_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_decorations_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.load_wallust_colors then
          user_decorations_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_decorations_helper then
    error("Failed to load user_decorations_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local load_wallust_colors = user_decorations_helper.load_wallust_colors

local wallust = load_wallust_colors(wallust_colors_file)
local function wallust_color(name, fallback)
  local value = wallust[name]
  if value ~= nil then
    return value
  end
  return fallback
end

hl.config({
  general = {
    border_size = 2,
    gaps_in = 2,
    gaps_out = 4,
    col = {
      active_border = wallust_color("color12", "rgba(8db4ffff)"),
      inactive_border = wallust_color("color10", "rgba(5f6578ff)"),
    },
  },
})

hl.config({
  decoration = {
    rounding = 10,
    active_opacity = 1.0,
    inactive_opacity = 0.9,
    fullscreen_opacity = 1.0,
    dim_inactive = true,
    dim_strength = 0.1,
    dim_special = 0.8,
    shadow = {
      enabled = true,
      range = 3,
      render_power = 1,
      color = wallust_color("color12", "rgba(8db4ffff)"),
      color_inactive = wallust_color("color10", "rgba(5f6578ff)"),
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      xray = true,
      ignore_opacity = true,
      special = true,
      popups = true,
    },
  },
})

hl.config({
  group = {
    col = {
      border_active = wallust_color("color15", "rgba(ffffffff)"),
    },
    groupbar = {
      col = {
        active = wallust_color("color0", "rgba(0f111aff)"),
      },
    },
  },
})

-- Source reference from UserDecorations.conf (hyprlang):
-- source = $HOME/.config/hypr/wallust/wallust-hyprland.conf
-- general {
-- border_size = 2
-- gaps_in = 2
-- gaps_out = 4
-- col.active_border = $color12
-- col.inactive_border = $color10
-- }
-- decoration {
-- rounding = 10
-- active_opacity = 1.0
-- inactive_opacity = 0.9
-- fullscreen_opacity = 1.0
-- dim_inactive = true
-- dim_strength = 0.1
-- dim_special = 0.8
-- shadow {
-- enabled = true
-- range = 3
-- render_power = 1
-- color =  $color12
-- color_inactive = $color10
-- }
-- blur {
-- enabled = true
-- size = 6
-- passes = 3
-- new_optimizations = true
-- xray = true
-- ignore_opacity = true
-- special = true
-- popups = true
-- }
-- }
-- group {
-- col.border_active = $color15
-- groupbar {
-- col.active = $color0
-- }
-- }
