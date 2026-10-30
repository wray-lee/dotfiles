# niri 26.04 desktop — port of the Hyprland setup

A self-contained desktop for niri 26.04 (new touchscreen laptop), built to feel
like the existing Hyprland session. Nothing outside `~/.config/niri/` is edited.
The only additions elsewhere are new waybar files (`ModulesNiri`,
`ModulesNiriOverrides`, `configs/[TOP] Niri Laptop`, `config-niri`); existing
waybar files, `~/.config/hypr`, `~/.config/wlogout`, `~/.config/rofi`,
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
| `scripts/dropdown.sh` | Toggle (or `--prewarm`) the kitty+tmux dropdown. |
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
| `scripts/kill-window.sh` | Kill the focused process. |
| `scripts/lid.sh` | Lid policy from `switch-events` (panel off behind an external). |
| `scripts/clipmanager.sh` | cliphist + rofi clipboard history. |
| `scripts/rofi-emoji.sh`, `scripts/rofi-calc.sh`, `scripts/rofi-beats.sh` | Rofi menus. |
| `scripts/zsh-theme.sh` | Change the Oh-My-Zsh theme. |
| `scripts/weather.py` | Weather for the bar and the lock screen. |

## Key bindings

Main modifier is `SUPER` (`Mod`). Full list: `Mod+H` (or `Mod+Shift+/`) opens
niri's hotkey overlay, generated from these files.

- **Apps**: `Mod+S` rofi drun, `Ctrl+Alt+B` browser, `Mod+X` kitty, `Mod+E`
  thunar, `Mod+A` overview, `Mod+W` wallpaper, `Mod+Shift+W` effects,
  `Ctrl+Alt+W` random wallpaper, `Mod+period` emoji, `Mod+Alt+C` calculator,
  `Mod+Alt+V` clipboard, `Mod+Ctrl+S` window switcher, `Mod+Shift+M`
  rofi-beats, `Mod+Shift+O` zsh theme.
- **Bar**: `Mod+Ctrl+Alt+B` toggle bar, `Mod+Ctrl+B` style picker,
  `Mod+Alt+B` layout picker, `Mod+Alt+R` restart bar/notifications.
- **Windows**: `Mod+Shift+F` fullscreen, `Mod+Ctrl+F` maximize column,
  `Alt+Space` float, `Mod+Alt+Space` float every window on the workspace (on,
  not toggle — matches Hyprland's `allfloat`), `Mod+D`/`Mod+Escape` close,
  `Alt+F4` kill process, `Mod+P` float (pseudo-tile substitute), `Mod+Shift+I`
  tabbed column, `Mod+Alt+L` cycle width preset, `Mod+Alt+O` toggle opacity
  (blur substitute), `Mod+Ctrl+O`/`Mod+T` toggle opacity rule.
- **Workspaces**: `Mod+1..0` focus, `Mod+Ctrl+1..0` move column,
  `Mod+Tab`/`Mod+Shift+Tab` next/previous, `Mod+grave` previous,
  `Mod+Shift+arrows` move workspace to monitor, `Mod+U` toggle `scratch`,
  `Mod+Shift+U` move column to `scratch`.
- **Media/system**: `Mod+L` lock, `Ctrl+Alt+P` power menu, XF86 volume/mic/
  brightness/keyboard-backlight/transport keys, `Mod+N` night light,
  `Mod+Shift+N` notification centre, `XF86Rfkill` airplane mode.
- **Screenshots**: `Mod+Print` screen, `Mod+Shift+S` area; the `F6` fallbacks
  and the 5/10 s timers are in `conf/binds/screenshot.kdl`.
- **Pointer**: `XF86TouchpadToggle` / `Mod+Shift+T` toggle touchpad,
  `Mod+wheel` workspace/column navigation.

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
blueman-applet, and `dropdown.sh --prewarm` (Hyprland pre-warmed the dropdown
too). xwayland-satellite is started on demand by niri.

## Behaviour parity and deliberate differences

| Hyprland | niri port |
|---|---|
| Blur toggle (`Mod+Alt+O`) | niri has global + per-rule blur but **no runtime toggle**; the key toggles the window opacity rule instead. |
| Opacity presets | Static active/inactive and per-app values in `conf/window-rules.kdl`; `toggle-window-rule-opacity` changes the focused window at runtime. |
| Special workspace | Named workspace `scratch`; `Mod+U` toggles back to the previous workspace. |
| Dropdown terminal | Window parked on `scratch`; pre-warmed at login; `Mod+Shift+Return`. |
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
- On-screen keyboard and display rotation are **not ported**: no keyboard app is
  installed, `misc.kdl` does not bind `tablet-mode-*`, and there is no rotate
  script. The comments in `conf/misc.kdl` show the two lines needed if
  squeekboard is installed.
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
4. Install/verify: niri, waybar, rofi, swaync, wlogout, hyprlock, hypridle,
   wallust, awww, kitty, tmux, fcitx5, cliphist, wl-clipboard, grim, slurp,
   swappy, jq, playerctl, cava, wlsunset (or gammastep), xwayland-satellite,
   a polkit agent.
5. Log in with `niri-session` (or `niri --session`).
6. Smoke test: `Mod+L` locks, `Ctrl+Alt+P` opens the power menu, `Mod+Print`
   saves a screenshot, `Mod+Shift+Return` opens the dropdown instantly,
   `Mod+U` toggles scratch, `XF86TouchpadToggle`, `Mod+Shift+G`, `Mod+Ctrl+B`
   and `Mod+Alt+B`, and the bar's weather/cava/hint/settings modules.
7. `cd ~/.config && md5sum -c /tmp/niri-port/baseline.md5 --quiet`
   should print nothing (no existing file outside the port changed).

## Switching back

The Hyprland config, waybar config symlink and all shared daemons are untouched.
Log out and start the Hyprland session again. The niri waybar variant is only
selected by `config-niri` / `waybar-niri.sh`; the default `waybar/config`
symlink still points at the Hyprland laptop config.
