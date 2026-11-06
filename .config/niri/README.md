# niri 26.04 desktop — port of the Hyprland setup

A self-contained desktop for niri 26.04 (new touchscreen laptop), built to feel
like the existing Hyprland session. Nothing outside `~/.config/niri/` is edited.
The only additions elsewhere are new waybar files (`ModulesNiri`,
`ModulesNiriOverrides`, `configs/[TOP] Niri Laptop`, `config-niri`); existing
waybar files, `~/.config/hypr` (kept in this repo at `hypr/` next to this file), `~/.config/wlogout`, `~/.config/rofi`,
`~/.config/swaync` and `~/.config/wallust` are read-only inputs.

## How the pieces fit (design contract)

- **One concern per file, one writer per value.** `config.kdl` contains only
  `include` lines. Each `conf/*.kdl` owns one subject (input, outputs, layout,
  animations, startup, window rules, layer rules, screenshot/cursor/overview
  toggles); each `conf/binds/*.kdl` is a single `binds { }` block that niri
  merges with the others. A file may contain several top-level blocks when the
  subject needs it (`misc.kdl` has several toggles, `window-rules.kdl` several
  rules, `startup.kdl` several `spawn-at-startup` lines).
- **No file reads another file's internals.** KDL has no variables; scripts
  never parse config text. They use the public IPC (`niri msg --json`, `jq`) or
  plain CLI flags.
- **Generated overrides are an explicit contract.** `conf/local/touchpad.kdl`
  and `conf/local/gamemode.kdl` are included last by `config.kdl`. They ship as
  comment-only placeholders and are written only by `scripts/touchpad.sh` and
  `scripts/gamemode.sh`. niri hot-reloads them on write.
- **Isolation.** Shared daemons get niri-owned copies or CLI flags:
  `hypridle -c idle/hypridle.conf`, `hyprlock -c idle/hyprlock.conf`,
  `wlogout -l idle/wlogout.layout -C idle/wlogout.css`. The bar config only
  calls `$HOME/.config/niri/scripts/*`; no bar hook executes a Hyprland script.
- **Deliberate duplicate literals** (KDL cannot alias strings):
  1. the internal connector `eDP-1` in `conf/outputs.kdl` and
     `conf/input.kdl` (`touch { map-to-output }`). Rename it in both files if
     the new laptop names the panel differently;
  2. the screenshot directory, owned by `conf/misc.kdl` (`screenshot-path`)
     and mirrored in `scripts/lib/common.sh` (`screenshots_dir`), because
     scripts cannot read KDL.
- Scripts are bash with `set -euo pipefail`, use `$HOME` (never
  `/home/wray`), do one job each, and share only `scripts/lib/common.sh`.

Validate the whole config with:

```bash
niri validate -c ~/.config/niri/config.kdl   # must print: config is valid
```

## File map

| File | Purpose |
|---|---|
| `config.kdl` | Include manifest only (plus the two generated includes). |
| `conf/environment.kdl` | `environment { }`: session/XDG/Qt/GTK/fcitx5 variables. |
| `conf/input.kdl` | `input { }`: keyboard, touchpad, mouse, touch (pinned to eDP-1), tablet, gestures. |
| `conf/outputs.kdl` | The only place monitor mode/scale/position/VRR lives. |
| `conf/layout.kdl` | `layout { }`: gaps, borders, focus ring, column widths, struts. |
| `conf/animations.kdl` | `animations { }`: every duration and curve. |
| `conf/misc.kdl` | Cursor, screenshot path, hotkey overlay, overview, hot corners, blur quality, xwayland-satellite, switch-events (lid). |
| `conf/startup.kdl` | `spawn-at-startup` only. |
| `conf/window-rules.kdl` | `window-rule` blocks: round corners, blur, opacity, float, dropdown, per-app rules, not-portable notes. |
| `conf/layer-rules.kdl` | `layer-rule` blocks for rofi/swaync/waybar blur. |
| `conf/local/touchpad.kdl` | Generated include (touchpad on/off). |
| `conf/local/gamemode.kdl` | Generated include (animations off, gaps 0). |
| `conf/binds/apps.kdl` | Launchers, menus, wallpaper, bar, theme keys. |
| `conf/binds/windows.kdl` | Focus/move/resize/fullscreen/float/tabbed columns. |
| `conf/binds/workspaces.kdl` | Workspace declarations (1..10, scratch) and navigation. |
| `conf/binds/media-system.kdl` | XF86 keys, volume, brightness, lock, power. |
| `conf/binds/screenshot.kdl` | Screenshot keys (all via `screenshot.sh`). |
| `conf/binds/mouse-touch.kdl` | Mouse buttons/wheel, touchpad toggle. |
| `idle/hypridle.conf` | Idle policy for niri (warn 9 min, lock 10 min). |
| `idle/hyprlock.conf` | hyprlock config (niri copy). |
| `idle/colors.conf` | hyprlock palette, written by `scripts/wallust.sh`. |
| `idle/wlogout.layout`, `idle/wlogout.css` | Power menu layout/style for niri. |
| `portals/niri-portals.conf` | xdg-desktop-portal backend selection. |
| `scripts/lib/common.sh` | Paths and helpers (`notify`, `require`, niri JSON, dirs). Sourced only. |
| `scripts/polkit.sh` | Start exactly one polkit authentication agent. |
| `scripts/lock.sh` | Lock once; single owner of the hyprlock config path. |
| `scripts/battery.sh` | Print battery charge/state for the lock screen. |
| `scripts/wlogout.sh` | Power menu with margins sized from the focused output. |
| `scripts/refresh.sh` | Restart bar/notification UI, close rofi. |
| `scripts/waybar-niri.sh` | Launch/switch the niri bar config/style. |
| `scripts/cava.sh` | cava stream for the bar (`custom/cava_mviz`). |
| `scripts/theme-select.sh` | Pick a wallust palette, then reload clients. |
| `scripts/wallust.sh` | Recolour clients from the wallpaper/theme; writes `idle/colors.conf`. |
| `scripts/wallpaper-daemon.sh` | Start awww and restore the saved wallpaper. |
| `scripts/wallpaper-select.sh` | Pick a wallpaper per output, save state, recolour. |
| `scripts/wallpaper-random.sh` | Random wallpaper. |
| `scripts/wallpaper-effects.sh` | Wallpaper effects/transform, recolour. |
| `scripts/dropdown.sh` | Toggle the kitty+tmux dropdown. |
| `scripts/float-all.sh` | Float/unfloat every window on the workspace (`Mod+Alt+Space`). |
| `scripts/scratch-toggle.sh` | Toggle the `scratch` workspace (second press returns). |
| `scripts/gamemode.sh` | Toggle game mode (DND, fullscreen, no bar, no animations/gaps). |
| `scripts/touchpad.sh` | Toggle the touchpad via `conf/local/touchpad.kdl`. |
| `scripts/screenshot.sh` | Screen/window/area/timer screenshots + Open/Delete notification. |
| `scripts/sounds.sh` | UI sounds used by `screenshot.sh`. |
| `scripts/volume.sh` | Volume/mic control and notifications. |
| `scripts/media.sh` | MPRIS play/pause/next/previous/stop. |
| `scripts/brightness.sh`, `scripts/brightness-kbd.sh` | Panel and keyboard backlight. |
| `scripts/nightlight.sh` | wlsunset/gammastep blue-light filter with saved state. |
| `scripts/airplane.sh` | Toggle airplane mode. |
| `scripts/refresh-rate.sh` | Panel refresh rate follows the power profile (power-saver 60 Hz, otherwise 120 Hz). |
| `scripts/kill-window.sh` | Kill the focused process. |
| `scripts/lid.sh` | Lid policy from `switch-events` (panel off behind an external). |
| `scripts/clipmanager.sh` | cliphist + rofi clipboard history. |
| `scripts/rofi-emoji.sh`, `scripts/rofi-calc.sh`, `scripts/rofi-beats.sh` | Rofi menus. |
| `scripts/zsh-theme.sh` | Change the Oh-My-Zsh theme. |
| `scripts/weather.py` | Weather for the bar and the lock screen. |

## Key bindings

Main modifier is `SUPER` (`Mod`). `Mod+H` (or `Mod+Shift+/`, `Mod+Shift+K`) opens
niri's hotkey overlay, generated from `conf/binds/*.kdl`; that is the source of
truth, the tables below mirror it. niri lays windows out as columns that run
horizontally, each column stacking windows vertically, so "column" below is
Hyprland's "window" in most cases.

### Apps and menus (`conf/binds/apps.kdl`)

| Keys | Action |
|---|---|
| `Mod+S` | App launcher (rofi drun) |
| `Ctrl+Alt+B` | Default browser |
| `Mod+X` | Terminal (kitty) |
| `Mod+E` | File manager (thunar) |
| `Mod+A` | Overview |
| `Mod+Ctrl+S` | Window switcher (rofi) |
| `Mod+period` | Emoji menu |
| `Mod+Alt+C` | Calculator |
| `Mod+Alt+V` | Clipboard history |
| `Mod+Shift+M` | Online music (rofi-beats) |
| `Mod+Shift+O` | Change zsh theme |
| `Mod+Alt+R` | Refresh bar and notification UI |
| `Mod+Ctrl+I` | Restart fcitx5 (it sometimes shows candidates but stops committing text) |
| `Mod+Shift+Return` | Dropdown terminal (kitty + tmux, first press starts it) |
| `Mod+W`, `Mod+Shift+W`, `Ctrl+Alt+W` | Wallpaper select / effects / random |
| `Mod+Ctrl+Alt+B` | Toggle waybar |
| `Mod+Ctrl+B`, `Mod+Alt+B` | Waybar style / layout menu |
| `Mod+N` | Toggle night light |
| `Mod+Shift+G` | Game mode (`scripts/gamemode.sh`) |
| `Mod+Shift+N` | Notification centre |
| `F13` | Laptop's side custom key: open hellfire. The hardware sends `KEY_F13`, which `us` does not map; `conf/input.kdl` loads `fkeys:basic_13-24` to give it a keysym. |

### Windows and columns (`conf/binds/windows.kdl`)

| Keys | Action |
|---|---|
| `Mod+D`, `Mod+Escape` | Close window |
| `Alt+F4` | Kill the window's process |
| `Ctrl+Alt+Delete` | Exit niri |
| `Mod+Shift+F` | Fullscreen |
| `Mod+Ctrl+F` | Maximize column |
| `Alt+Space`, `Mod+P` | Toggle floating (`Mod+P` replaces Hyprland's pseudo tile) |
| `Mod+Alt+Space` | Float every window on the workspace (on, not toggle) |
| `Mod+Ctrl+O`, `Mod+T`, `Mod+Alt+O` | Toggle the opacity rule (niri has no runtime blur toggle) |
| `Ctrl+Alt+Left/Right` | Focus column left / right (or monitor) |
| `Ctrl+Alt+Up/Down` | Focus window up / down (or monitor) |
| `Alt+Tab` | Previously focused window |
| `Mod+Left/Right` | Move column left / right |
| `Mod+Up/Down` | Move window up / down in the column |
| `Mod+Alt+Left/Right` | Narrow / widen column |
| `Mod+Alt+Up/Down` | Shorten / heighten window |
| `Mod+Alt+L` | Cycle column width preset |
| `Mod+M` | Column width 30% |
| `Mod+I` | Consume window into column |
| `Mod+Ctrl+D`, `Mod+Ctrl+H` | Expel window from column |
| `Mod+Ctrl+K`, `Mod+Ctrl+L` | Consume or expel window left / right |
| `Mod+Ctrl+Return` | Move column to first |
| `Mod+Shift+I`, `Mod+G` | Toggle tabbed column (group) |
| `Mod+Ctrl+Tab`, `Mod+Ctrl+Shift+Tab` | Next / previous window in the column |

### Workspaces (`conf/binds/workspaces.kdl`)

Workspaces `1` to `10` plus the named `scratch` workspace.

| Keys | Action |
|---|---|
| `Mod+1` .. `Mod+0` | Go to workspace 1..10 |
| `Mod+Ctrl+1` .. `Mod+Ctrl+0` | Move column to workspace 1..10 |
| `Mod+Tab`, `Mod+Shift+Tab` | Next / previous workspace |
| `Mod+grave` | Previously focused workspace |
| `Mod+Ctrl+[` / `Mod+Ctrl+]` | Move column to previous / next workspace |
| `Mod+Shift+Left/Right/Up/Down` | Move the workspace to the monitor in that direction |
| `Mod+U` | Toggle `scratch` (second press returns) |
| `Mod+Shift+U` | Move column to `scratch` |

### System and media (`conf/binds/media-system.kdl`)

| Keys | Action |
|---|---|
| `Mod+L` | Lock screen |
| `Ctrl+Alt+P` | Power menu (wlogout) |
| `XF86Audio*` | Volume, mic mute, transport keys (also while locked) |
| `XF86MonBrightness*`, `XF86KbdBrightness*` | Panel / keyboard backlight |
| `XF86Sleep`, `XF86Rfkill` | Suspend, airplane mode |
| `XF86Launch1/3/4` | ROG Control Center, keyboard RGB profile, fan profile |

### Screenshots (`conf/binds/screenshot.kdl`)

| Keys | Action |
|---|---|
| `Mod+Print`, `Mod+F6` | Screen |
| `Mod+Shift+S`, `Mod+Shift+F6` | Area |
| `Alt+F6` | Active window |
| `Mod+Ctrl+F6`, `Mod+Alt+F6` | Screen after 5 s / 10 s |

### Pointer and touch (`conf/binds/mouse-touch.kdl`, `scripts/gestures.sh`)

| Input | Action |
|---|---|
| `XF86TouchpadToggle`, `Mod+Shift+T` | Toggle touchpad |
| `Mod+wheel down/up` | Next / previous workspace |
| `Mod+Ctrl+wheel down/up` | Move column to next / previous workspace |
| `Mod+wheel left/right` | Focus column left / right |
| `Mod+Ctrl+wheel left/right` | Move column left / right |
| Touchscreen: 3 fingers up / down | Show / hide the on-screen keyboard |
| Touchscreen: 3 fingers left / right | Focus the column to the right / left |
| Touchscreen: 4 fingers up | Overview |
| Touchscreen: swipe down from top edge | Notification centre |
| Touchscreen: swipe up from bottom edge | App launcher (nwg-drawer) |

## Waybar integration

`configs/[TOP] Niri Laptop` includes, in this order:

1. `ModulesNiri` — compositor modules (`niri/workspaces`, `niri/window` with
   `rewrite`, `niri/language`, `group/status_niri`).
2. `ModulesNiriOverrides` — redefines **every** hook that would otherwise run
   a `~/.config/hypr/...` script (backlight, battery, audio, weather, cava,
   menus, hints, settings, dot_update, power/lock). It must stay before the
   shared files: waybar keeps the **first** definition it sees.
3. `Modules`, `ModulesCustom`, `ModulesGroups`, `UserModules` — shared KooL
   definitions; only untouched, compositor-neutral modules are used from here.

There is no niri-specific style file. The bar uses the shared `style.css`
symlink by default; `scripts/waybar-niri.sh --style` lets you pick any style in
`~/.config/waybar/style/` and remembers the choice in
`$XDG_STATE_HOME/niri/waybar-style` without rewriting shared files.

## What starts what

`conf/startup.kdl` starts: polkit agent, wallpaper daemon (also recolours),
night-light restore, swaync, waybar (`waybar-niri.sh Laptop`), hypridle with
`idle/hypridle.conf`, fcitx5, two cliphist watchers, nm-applet,
blueman-applet, autofill, refresh-rate and gestures. The dropdown is not
pre-warmed (unlike Hyprland); it starts on the first `Mod+Shift+Return`.
xwayland-satellite is started on demand by niri.

## Behaviour parity and deliberate differences

| Hyprland | niri port |
|---|---|
| Blur toggle (`Mod+Alt+O`) | niri has global + per-rule blur but **no runtime toggle**; the key toggles the window opacity rule instead. |
| Opacity presets | Static active/inactive and per-app values in `conf/window-rules.kdl`; `toggle-window-rule-opacity` changes the focused window at runtime. |
| Special workspace | Named workspace `scratch`; `Mod+U` toggles back to the previous workspace. |
| Dropdown terminal | Window parked on `scratch`; started on first use, not at login; `Mod+Shift+Return`. |
| Touchpad toggle | Works: `conf/local/touchpad.kdl` is included and hot-reloaded. |
| Game mode | Works: animations off + gaps 0 via `conf/local/gamemode.kdl`, DND, fullscreen, bar stopped (restored on exit). |
| Power menu | `wlogout.sh` uses `idle/wlogout.layout`; Logout is `niri msg action quit --skip-confirmation`. |
| Lock screen | One config: `idle/hyprlock.conf` (colours `idle/colors.conf`). `lock.sh` is the only locker entry point: `Mod+L`, bar lock, hypridle `lock_cmd`. |
| Screenshots | All keys run `screenshot.sh`; names match `screenshot-path` (`Screenshot %Y-%m-%d %H-%M-%S.png`) and keep the Open/Delete notification. |
| Idle policy | Warn 9 min, lock 10 min. Screen-off at 12 min and auto-suspend at 20 min stay disabled, as they were in `~/.config/hypr/hypridle.conf`. |
| CSD | Clients keep their client-side decorations (same as Hyprland); `prefer-no-csd` is not set. |
| Lid | `switch-events` calls `lid.sh`: with an external monitor it only turns the internal panel off. With no external monitor logind suspends; hypridle then locks. |
| Keybinds overlay | `Mod+H` / `Mod+Shift+/` show niri's generated overlay; the bar's `custom/hint` opens the same overlay. |
| Waybar styles/layouts | Both menus work (`--style`, `--layout`); no separate niri style file is shipped. |

## Known limitations

- `niri 26.04` has no runtime blur toggle, no per-workspace layout, no overlay/
  scratchpad workspace (named workspace instead), no idle-inhibit window rule,
  no modifier-only/release binds, no compositor zoom, and no pipe-to-editor for
  screenshots. Each gap is recorded in the relevant `.kdl` comment.
- Touch is pinned to `eDP-1` in `conf/input.kdl`. If the new laptop names its
  panel differently, `niri msg outputs` will show it; update both
  `conf/outputs.kdl` and the `touch { map-to-output }` line. A wrong name is
  ignored (touch falls back to the union of outputs).
- On-screen keyboard: `scripts/osk.sh show|hide|toggle` drives squeekboard over
  D-Bus (fcitx5 holds input-method-v2, so it never pops up on text focus). The
  laptop has no tablet-mode switch, so `udev/90-osk-keyboard-cover.rules` shows
  it when the keyboard cover is detached and hides it when attached; the waybar
  `custom/osk` button toggles it by touch. Its layout is squeekboard's terminal
  layout (arrows, Esc/Tab/Ctrl/Alt); landscape is a custom 15-column laptop layout,
  installed as `us.yaml`/`us_wide.yaml` and `terminal/` (used when a terminal has focus) in
  `~/.local/share/squeekboard/keyboards/`. The rule must be installed into
  `/etc/udev/rules.d/` (command in the file). Display rotation is **not ported**.
- Window widths: niri has no "fill when alone" option, so `scripts/autofill.sh`
  follows the IPC event stream and, when a workspace's tiled column count
  changes, sets 1 column to 100% and 2 columns to 50% each (3+ scroll as usual).
  It only acts on a count change, so manual resizes stick.
- Touchscreen gestures: niri has no configurable touch gestures, so
  `scripts/gestures.sh` runs lisgd (AUR) with its own gesture table (3 fingers
  up/down = keyboard show/hide, 3 left/right = columns, 4 up = overview, edge
  swipes = notifications / launcher). It needs
  `udev/70-touchscreen-uaccess.rules` installed to read the touchscreen.
- The dropdown's y-offset is fixed at 120 px (10% of the internal panel's
  1200 px logical height); on a different-height panel it is approximate.
- `hyprlock` v0.9.6 ignores the inherited `grace` option, so it was removed
  from the niri copy; `fractional_scaling` and the rest parse cleanly.
- Aiming a screenshot or recording at another output is not scripted; use the
  native screenshot UI (`screenshot.sh --ui`).

## Moving to the new laptop

1. `niri validate -c ~/.config/niri/config.kdl`.
2. `niri msg outputs`; if the panel is not `eDP-1`, rename it in
   `conf/outputs.kdl` and in `conf/input.kdl` (`touch { map-to-output }`).
3. Check the external monitor's model string in `conf/outputs.kdl`.
4. Install/verify: niri, waybar, rofi, nwg-drawer (touch launcher), swaync, wlogout, hyprlock, hypridle,
   wallust, awww, kitty, tmux, fcitx5, cliphist, wl-clipboard, grim, slurp,
   swappy, jq, playerctl, cava, wlsunset (or gammastep), xwayland-satellite,
   a polkit agent.
5. Log in with `niri-session` (or `niri --session`).
6. Smoke test: `Mod+L` locks, `Ctrl+Alt+P` opens the power menu, `Mod+Print`
   saves a screenshot, `Mod+Shift+Return` opens the dropdown (about a second the first time),
   `Mod+U` toggles scratch, `XF86TouchpadToggle`, `Mod+Shift+G`, `Mod+Ctrl+B`
   and `Mod+Alt+B`, and the bar's weather/cava/hint/settings modules.
7. `cd ~/.config && md5sum -c /tmp/niri-port/baseline.md5 --quiet`
   should print nothing (no existing file outside the port changed).

## Switching back

The Hyprland config, waybar config symlink and all shared daemons are untouched.
Log out and start the Hyprland session again. The niri waybar variant is only
selected by `config-niri` / `waybar-niri.sh`; the default `waybar/config`
symlink still points at the Hyprland laptop config.
