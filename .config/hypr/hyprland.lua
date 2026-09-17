-- Hyprland Lua Configuration
-- Migrated for Hyprland 0.56+ / 0.57

------------------
---- MONITORS ----
------------------
hl.monitor({
    output = "desc:Lenovo Group Limited 0x8A90",
    mode = "2880x1800@60.0",
    position = "0x1440",
    scale = 1.5,
})

hl.monitor({
    output = "desc:Hisense Electric Co. Ltd. HISENSE 0x01010101",
    mode = "2560x1440@59.95",
    position = "1920x0",
    scale = 1.0,
})

-- Fallback for any other / internal display
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
})

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/Polkit.sh")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("swaync")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/Hyprsunset.sh init")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/WallpaperDaemon.sh")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("cc-switch")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("EDITOR", "nvim")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        border_size = 2,
        gaps_in = 2,
        gaps_out = 4,
        layout = "dwindle",
        resize_on_border = true,
        col = {
            active_border = "rgba(8db4ffff)",
            inactive_border = "rgba(5f6578ff)",
        },
    },
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
            color = "rgba(8db4ffff)",
            color_inactive = "rgba(5f6578ff)",
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
    dwindle = {
        preserve_split = true,
        smart_resizing = true,
        use_active_for_splits = true,
        smart_split = false,
        default_split_ratio = 1.0,
        split_bias = 0,
        precise_mouse_move = false,
        special_scale_factor = 0.8,
    },
    master = {
        new_status = "slave",
        new_on_top = false,
        new_on_active = "none",
        orientation = "left",
        mfact = 0.55,
        smart_resizing = true,
        drop_at_cursor = true,
    },
    scrolling = {
        column_width = 0.80,
        fullscreen_on_one_column = true,
        direction = "right",
        follow_focus = true,
    },
    input = {
        kb_layout = "us",
        repeat_rate = 50,
        repeat_delay = 300,
        sensitivity = 0,
        numlock_by_default = true,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_touch = false,
        workspace_swipe_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_create_new = true,
        workspace_swipe_direction_lock = true,
        workspace_swipe_forever = false,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 2,
        mouse_move_enables_dpms = true,
        enable_swallow = false,
        enable_anr_dialog = true,
        anr_missed_pings = 15,
        allow_session_lock_restore = true,
        on_focus_under_fullscreen = 1,
    },
    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    },
    cursor = {
        enable_hyprcursor = true,
        warp_on_change_workspace = 2,
        no_warps = true,
        zoom_factor = 1.0,
        hide_on_key_press = true,
    },
})

--------------------
---- ANIMATIONS ----
--------------------
hl.curve("wind",      { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn",     { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut",    { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("liner",     { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })
hl.curve("overshot",  { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.5, 0 }, { 0.99, 0.99 } } })
hl.curve("smoothIn",  { type = "bezier", points = { { 0.5, -0.5 }, { 0.68, 1.5 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "wind", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smoothOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "liner", style = "loop" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "winOut", style = "slide" })

---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"))
hl.bind("CTRL + ALT + B", hl.dsp.exec_cmd("xdg-open 'https://'"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(scripts .. "/OverviewToggle.sh"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(scripts .. "/KeyHints.sh"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd(scripts .. "/Refresh.sh"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(scripts .. "/RofiEmoji.sh"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd(scripts .. "/ChangeBlur.sh"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(scripts .. "/GameMode.sh"))
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd(scripts .. "/ChangeLayout.sh"))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd(scripts .. "/ClipManager.sh"))
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd(scripts .. "/RofiThemeSelector.sh"))
hl.bind(mainMod .. " + CTRL + SHIFT + R", hl.dsp.exec_cmd("pkill rofi || true && " .. scripts .. "/RofiThemeSelector-modified.sh"))

hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("ALT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat"))

hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("hyprctl dispatch exit 0"))
hl.bind(mainMod .. " + D", hl.dsp.window.close())
hl.bind(mainMod .. " + ESCAPE", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.exec_cmd(scripts .. "/KillActiveProcess.sh"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(scripts .. "/LockScreen.sh"))
hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd(scripts .. "/Wlogout.sh"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(scripts .. "/Kool_Quick_Settings.sh"))

hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --now"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --area"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/Volume.sh --inc"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/Volume.sh --dec"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scripts .. "/Volume.sh --toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/Volume.sh --toggle-mic"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --nxt"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --prv"), { locked = true })

hl.bind(mainMod .. " + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.window.move({ direction = "down" }))

hl.bind("CTRL + ALT + left", hl.dsp.focus({ direction = "left" }))
hl.bind("CTRL + ALT + right", hl.dsp.focus({ direction = "right" }))
hl.bind("CTRL + ALT + up", hl.dsp.focus({ direction = "up" }))
hl.bind("CTRL + ALT + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + ALT + left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -50 0"), { repeating = true })
hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 50 0"), { repeating = true })
hl.bind(mainMod .. " + ALT + up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -50"), { repeating = true })
hl.bind(mainMod .. " + ALT + down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 50"), { repeating = true })

hl.bind(mainMod .. " + SHIFT + left", hl.dsp.exec_cmd("hyprctl dispatch movecurrentworkspacetomonitor l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movecurrentworkspacetomonitor r"))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.exec_cmd("hyprctl dispatch movecurrentworkspacetomonitor u"))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.exec_cmd("hyprctl dispatch movecurrentworkspacetomonitor d"))

for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("hyprctl getoption decoration:inactive_opacity | grep -q 'float: 0.9' && hyprctl --batch 'keyword decoration:active_opacity 1.2; keyword decoration:inactive_opacity 1.2' || hyprctl --batch 'keyword decoration:active_opacity 1.0; keyword decoration:inactive_opacity 0.9'"))

----------------------
---- WINDOW RULES ----
----------------------
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true },
    no_focus = true,
})

hl.window_rule({
    name = "pip",
    match = { title = "^[Pp]icture-in-[Pp]icture$" },
    float = true,
    pin = true,
})

hl.window_rule({
    name = "auth-dialogs",
    match = { title = "^(Authentication Required|Authentication required)$" },
    float = true,
    center = true,
})
