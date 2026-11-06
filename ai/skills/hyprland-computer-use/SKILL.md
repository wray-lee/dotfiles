---
name: hyprland-computer-use
description: Operate desktop GUI apps on a Wayland/Hyprland Linux machine by screenshot plus synthetic mouse and keyboard, like macOS computer use. Use when the task needs clicking, typing or reading a native desktop app that has no CLI or API. For websites use the Playwright MCP instead.
---

# Hyprland computer use

Helper: `cu` in this skill's directory (bash). Run it with no args for usage. It finds `HYPRLAND_INSTANCE_SIGNATURE` and `WAYLAND_DISPLAY` itself, so it also works from ssh.

## Before first use
Run `cu doctor`, then `cu calibrate`. If any line says FAIL, stop and tell the user the fix, do not work around it:
- `/dev/uinput` not writable: user needs `sudo usermod -aG input $USER`, then log out and back in.
- ydotoold not running (keyboard only): `systemctl --user enable --now ydotool`.
- monitor asleep (dpms off): `grim` blocks forever. Moving the pointer (`cu move 10 10`) wakes it.
- `calibrate` FAIL: do not click, the pointer is not landing where asked.

## How input works (do not "simplify" this)
- Mouse: `pointer.py` creates an **absolute** virtual pointer on /dev/uinput; `cu` starts it on first use and feeds it through a FIFO. Positions are exact.
- Do NOT use `ydotool mousemove`/`click`: its pointer is relative and goes through pointer acceleration, so it lands in the wrong place.
- Keyboard: ydotool `key`.
- `cu pos` prints the real pointer position (from `hyprctl cursorpos`) in the same coordinates as `click`. Use it to check a move.

## Loop
1. `cu shot` prints a PNG path. Read it. Coordinates are logical pixels of that image, origin top-left, and the same space `cu click` takes. A rotated monitor is handled: coordinates follow the rotated picture.
2. Act with one command: `click x y [right|double]`, `drag`, `scroll`, `type`, `key`.
3. `cu shot` again and check the result before the next step. Never chain several blind clicks.

## Rules
- `cu type "text"` pastes through the clipboard (works for Chinese), and restores the old clipboard. In terminals pass the paste combo: `cu type "text" ctrl+shift+v`.
- `cu key` takes combos like `ctrl+l`, `super+1`, `enter`, `esc`. Names come from linux `KEY_*`.
- `cu windows` lists windows (address, focused `*`, class, title). `cu focus ADDRESS` switches. Prefer this over clicking to change windows. On Hyprland 0.5x+ dispatchers are Lua (`hl.dsp.focus({ window = "address:0x.." })`); `cu focus` falls back to the classic syntax on older versions.
- A fullscreen window (e.g. a game-stream client) covers everything: check `cu windows` first and do not input into it by accident.
- Click and type are real actions. Confirm with the user before anything destructive or outward-facing (send, delete, pay, submit, close unsaved work).
- Do not type passwords or read secrets off the screen.
- Single monitor only. Multi-monitor mapping is untested.

## Verified (eDP-1 rotated 90deg, 1200x1920 logical, scale 1.5, Hyprland 0.57.0)
`calibrate` PASS (4 points, exact). `windows`, `focus`, `shot`, `doctor` work. Click, right-click, wheel and drag use the same daemon that was verified on niri, but were not exercised on Hyprland, to avoid disturbing the live desktop.
