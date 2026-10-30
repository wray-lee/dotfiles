#!/usr/bin/env bash
# Toggle a floating dropdown terminal (kitty + tmux session).
#
# niri has no "hide window" action, so the window is parked on the named
# "scratch" workspace while hidden: it stays mapped off-screen. `tmux new -A`
# keeps the session, so hide/show behaves like a Hyprland dropdown.
#
# Usage: dropdown.sh [-d|--debug] [--prewarm]
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

APP_ID="kitty-dropterm"
SCRATCH_WS="scratch"
LOCK_FILE="/tmp/niri-dropdown.lock"
LAST_FILE="/tmp/niri-dropdown.last"
DEBOUNCE_MS=250

DEBUG=false
PREWARM=false
for arg in "$@"; do
    case "$arg" in
        -d | --debug) DEBUG=true ;;
        --prewarm) PREWARM=true ;;
        -h | --help) printf 'usage: %s [-d|--debug] [--prewarm]\n' "$0"; exit 0 ;;
        *)
            printf 'unknown option: %s\n' "$arg" >&2
            exit 2
            ;;
    esac
done

log() {
    if $DEBUG; then
        printf '[dropdown] %s\n' "$*" >&2
    fi
}

require niri "niri compositor"
require jq jq
require kitty kitty
require tmux tmux
require flock util-linux
require date coreutils

# Serialise toggles and drop rapid repeats (double activation of the bind).
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0
now_ms=$(date +%s%3N)
if [[ -f $LAST_FILE ]]; then
    last_ms=$(<"$LAST_FILE")
    if ((now_ms - last_ms < DEBOUNCE_MS)); then
        exit 0
    fi
fi
printf '%s\n' "$now_ms" >"$LAST_FILE"

window_id() {
    niri_json windows |
        jq -r --arg app "$APP_ID" 'first(.[] | select(.app_id == $app) | .id) // empty'
}

workspace_of_window() {
    niri_json windows |
        jq -r --argjson i "$1" 'first(.[] | select(.id == $i) | .workspace_id) // empty'
}

workspace_name() {
    niri_json workspaces |
        jq -r --argjson w "$1" 'first(.[] | select(.id == $w) | .name) // empty'
}

spawn_dropdown() {
    niri msg action spawn -- kitty --app-id "$APP_ID" -e tmux new -A -s dropdown
}

hide_window() {
    niri msg action move-window-to-workspace "$SCRATCH_WS" --window-id "$1" --focus false
}

id=$(window_id)

if [[ -z $id ]]; then
    log "no dropdown window, spawning"
    spawn_dropdown
    if $PREWARM; then
        for _ in {1..30}; do
            id=$(window_id)
            [[ -n $id ]] && break
            sleep 0.1
        done
        if [[ -n $id ]]; then
            hide_window "$id"
        fi
    fi
    exit 0
fi

ws=$(workspace_of_window "$id")

if $PREWARM; then
    # Already running: make sure it is parked on the hidden workspace.
    if [[ $(workspace_name "$ws") != "$SCRATCH_WS" ]]; then
        hide_window "$id"
    fi
    exit 0
fi

if [[ $(workspace_name "$ws") == "$SCRATCH_WS" ]]; then
    current_idx=$(niri_json workspaces | jq -r 'first(.[] | select(.is_focused) | .idx) // empty')
    log "showing on workspace ${current_idx:-?}"
    niri msg action move-window-to-workspace "$current_idx" --window-id "$id" --focus false
    niri msg action focus-window --id "$id"
    niri msg action move-floating-window --id "$id" -x "17.5%" -y "10%"
else
    log "hiding to $SCRATCH_WS"
    hide_window "$id"
fi
