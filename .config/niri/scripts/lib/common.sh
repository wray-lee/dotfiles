#!/usr/bin/env bash
# Tiny shared helpers for niri port scripts. No compositor policy here.
#
# Sourced (never executed) by the scripts in this directory. Keep this file
# small: helpers only, no behaviour that belongs to a single script.

# ---- single source for paths used by more than one script ------------------
: "${NIRI_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/niri}"
: "${STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/niri}"
# Symlink to the current wallpaper, maintained by wallpaper-select.sh.
: "${WALLPAPER_STATE:=$STATE_DIR/wallpaper}"
# Existing rofi symlink (read/written only to preserve the current UX).
: "${ROFI_CURRENT_WALLPAPER:=$HOME/.config/rofi/.current_wallpaper}"

pictures_dir() { xdg-user-dir PICTURES 2>/dev/null || printf '%s/Pictures\n' "$HOME"; }
wallpapers_dir() { printf '%s/wallpapers\n' "$(pictures_dir)"; }
# conf/misc.kdl owns screenshot-path. KDL has no variables and scripts must not
# parse config text, so this is the matching literal for screenshot.sh; keep
# the two in sync (documented duplicate).
screenshots_dir() { printf '%s/Screenshots\n' "$(pictures_dir)"; }

# ---- niri IPC JSON helpers -------------------------------------------------
niri_json() { niri msg --json "$1"; }

focused_output_name() {
    niri_json focused-output | jq -r '.name // empty'
}

# "width<TAB>height<TAB>scale" in logical pixels of the focused output
focused_output_logical() {
    niri_json focused-output |
        jq -r '[.logical.width, .logical.height, .logical.scale] | @tsv'
}

focused_window_id() { niri_json focused-window | jq -r '.id // empty'; }

# ---- dependency / notification helpers -------------------------------------
need() {
    command -v "$1" >/dev/null 2>&1 || {
        notify-send -u normal -t 5000 "${2:-Missing dependency}" "Install: $1" 2>/dev/null || true
        printf 'missing dependency: %s\n' "$1" >&2
        exit 127
    }
}

# Alias for the name used by the script contract.
require() { need "$@"; }

notify() { notify-send -a niri "$@" 2>/dev/null || true; }
