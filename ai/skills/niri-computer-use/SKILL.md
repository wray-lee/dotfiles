---
name: niri-computer-use
description: Operate desktop GUI apps on this Wayland/niri Linux machine by screenshot plus synthetic mouse and keyboard, like macOS computer use. Use when the task needs clicking, typing or reading a native desktop app that has no CLI or API. For websites use the Playwright MCP instead.
---

# niri computer use

Helper: `cu` in this skill's directory (bash). Run it with no args for usage.

## Before first use
Run `cu doctor`. If any line says FAIL, stop and tell the user the fix, do not work around it:
- `/dev/uinput` not writable: user needs `sudo usermod -aG input $USER`, then log out and back in.
- ydotoold not running (keyboard only): `systemctl --user enable --now ydotool`.

## How input works (do not "simplify" this)
- Mouse: `pointer.py` creates an **absolute** virtual pointer on /dev/uinput; `cu` starts it on first use and feeds it through a FIFO. Positions are exact.
- Do NOT use `ydotool mousemove`/`click`: its pointer is relative and goes through the user's adaptive acceleration, so it lands in the wrong place.
- Keyboard: ydotool `key`.

## Loop
1. `cu shot` prints a PNG path. Read it. Coordinates are logical pixels of that image, origin top-left, and the same space `cu click` takes.
2. Act with one command: `click x y [right|double]`, `drag`, `scroll`, `type`, `key`.
3. `cu shot` again and check the result before the next step. Never chain several blind clicks.

## Rules
- `cu type "text"` pastes through the clipboard (works for Chinese), and restores the old clipboard. In terminals pass the paste combo: `cu type "text" ctrl+shift+v`.
- `cu key` takes combos like `ctrl+l`, `super+1`, `enter`, `esc`. Names come from linux `KEY_*`.
- `cu windows` lists niri windows (id, focused `*`, app_id, title). `cu focus ID` switches. Prefer this over clicking to change windows.
- The pointer is often missing from `cu shot` in terminals (they hide it). Do not treat that as a failed move.
- Click and type are real actions. Confirm with the user before anything destructive or outward-facing (send, delete, pay, submit, close unsaved work).
- Do not type passwords or read secrets off the screen.
- Single output only. Multi-monitor mapping is untested.
- Failing clicks: re-run `cu shot`, the layout may have moved. Check focus with `cu windows`.

## Verified (eDP-1, 1920x1200 logical, scale 1.5)
Absolute moves are linear to the pixel; left/right click, wheel and drag land where requested (checked with a kitty mouse-reporting probe).
