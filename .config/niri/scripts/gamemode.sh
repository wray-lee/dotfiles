#!/usr/bin/env bash
# Toggle game mode: no animations, no gaps, DND, fullscreen, no bar.
#
# niri has no runtime animation/gaps IPC, so the generated include
# $NIRI_DIR/conf/local/gamemode.kdl is the only way to change them (hot reload).
# That file is generated: never hand-edit it.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

CONF="$NIRI_DIR/conf/local/gamemode.kdl"

# Match the generated statement, not the word "off" in the file's comment.
is_enabled() { grep -qE '^[[:space:]]*off;' "$CONF" 2>/dev/null; }

write_conf() {
    mkdir -p "$(dirname -- "$CONF")"
    printf 'animations {\n    off;\n}\n\nlayout {\n    gaps 0;\n}\n' >"$CONF"
}

game_on() {
    require niri "niri compositor"
    pkill -x waybar 2>/dev/null || true
    swaync-client -d -sw >/dev/null 2>&1 || true
    niri msg action fullscreen-window 2>/dev/null || true
    write_conf
    niri msg action do-screen-transition 2>/dev/null || true
    notify "Game mode" "Enabled"
}

game_off() {
    require niri "niri compositor"
    swaync-client -d -sw >/dev/null 2>&1 || true
    niri msg action fullscreen-window 2>/dev/null || true
    mkdir -p "$(dirname -- "$CONF")"
    : >"$CONF"
    niri msg action do-screen-transition 2>/dev/null || true
    # refresh.sh owns the waybar launch command (waybar-niri.sh); without
    # --no-waybar it restarts the bar that game_on stopped.
    if [[ -x "$SELF_DIR/refresh.sh" ]]; then
        "$SELF_DIR/refresh.sh" >/dev/null 2>&1 || true
    else
        printf 'gamemode: waybar was stopped; restart it with the niri waybar config\n' >&2
    fi
    notify "Game mode" "Disabled"
}

case "${1:-toggle}" in
    toggle)
        if is_enabled; then
            game_off
        else
            game_on
        fi
        ;;
    on) game_on ;;
    off) game_off ;;
    status)
        if is_enabled; then
            printf 'on\n'
        else
            printf 'off\n'
        fi
        ;;
    *)
        printf 'usage: %s {toggle|on|off|status}\n' "$0" >&2
        exit 2
        ;;
esac
