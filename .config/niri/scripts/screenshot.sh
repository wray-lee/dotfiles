#!/usr/bin/env bash
# Take a screenshot and notify with Open/Delete actions.
#
# Modes:
#   --now (default)  full screen, saved + copied to clipboard
#   --in5 / --in10   same, after a 5/10 s countdown
#   --win            focused window, saved + copied
#   --area           slurp region, saved + copied
#   --active         focused window, saved with its app id in the name
#   --swappy         slurp region, opened in swappy (not saved)
#   --ui             niri's native screenshot UI
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

MODE="now"
case "${1:---now}" in
    --now) MODE="now" ;;
    --in5) MODE="in5" ;;
    --in10) MODE="in10" ;;
    --win) MODE="win" ;;
    --area) MODE="area" ;;
    --active) MODE="active" ;;
    --swappy) MODE="swappy" ;;
    --ui) MODE="ui" ;;
    -h | --help)
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

require jq jq
ICON_PICTURE="$HOME/.config/swaync/icons/picture.png"
ICON_TIMER="$HOME/.config/swaync/icons/timer.png"

SHOTS_DIR=$(screenshots_dir)
mkdir -p "$SHOTS_DIR"

# Same strftime pattern as conf/misc.kdl screenshot-path, so native niri shots
# and script shots land with identical names.
stamp=$(date +'%Y-%m-%d %H-%M-%S')
file="$SHOTS_DIR/Screenshot $stamp.png"

play_sound() {
    if [[ -x "$SELF_DIR/sounds.sh" ]]; then
        "$SELF_DIR/sounds.sh" "$1" >/dev/null 2>&1 &
    fi
}

countdown() {
    local sec
    for ((sec = $1; sec > 0; sec--)); do
        notify-send -t 1000 -i "$ICON_TIMER" "Taking screenshot" "in ${sec}s"
        sleep 1
    done
}

# Notify with Open/Delete; waits at most 5 s for an action.
notify_view() {
    local path=$1 resp
    play_sound --screenshot
    resp=$(timeout 5 notify-send -t 10000 -A action1=Open -A action2=Delete \
        -h string:x-canonical-private-synchronous:shot-notify -i "$ICON_PICTURE" \
        "Screenshot saved" "$(basename -- "$path")" 2>/dev/null) || true
    case "$resp" in
        action1) xdg-open "$path" >/dev/null 2>&1 & ;;
        action2) rm -f -- "$path" ;;
    esac
}

notify_failed() {
    play_sound --error
    notify-send -u low -i "$ICON_PICTURE" "Screenshot" "NOT saved" || true
}

# Wait briefly for niri/magick to flush the file, then notify.
finish() {
    local path=$1
    for _ in {1..10}; do
        [[ -f $path ]] && break
        sleep 0.1
    done
    if [[ -f $path ]]; then
        notify_view "$path"
    else
        notify_failed
    fi
}

full_screen() {
    require niri "niri compositor"
    niri msg action screenshot-screen --write-to-disk true --show-pointer false --path "$file"
}

active_window() {
    require niri "niri compositor"
    local app
    app=$(niri_json focused-window | jq -r '.app_id // "window"')
    file="$SHOTS_DIR/Screenshot $stamp $app.png"
    niri msg action screenshot-window --write-to-disk true --show-pointer false --path "$file"
}

region_to_file() {
    local geo tmp
    require grim grim
    require slurp slurp
    require wl-copy wl-clipboard
    geo=$(slurp) || exit 0
    [[ -n $geo ]] || exit 0
    tmp=$(mktemp)
    if grim -g "$geo" - >"$tmp" && [[ -s $tmp ]]; then
        wl-copy <"$tmp"
        mv "$tmp" "$file"
        notify_view "$file"
    else
        rm -f "$tmp"
        notify_failed
    fi
}

case "$MODE" in
    now | in5 | in10)
        if [[ $MODE == in5 ]]; then countdown 5; fi
        if [[ $MODE == in10 ]]; then countdown 10; fi
        full_screen
        finish "$file"
        ;;
    win)
        require niri "niri compositor"
        niri msg action screenshot-window --write-to-disk true --show-pointer false --path "$file"
        finish "$file"
        ;;
    active)
        active_window
        finish "$file"
        ;;
    area)
        region_to_file
        ;;
    swappy)
        require grim grim
        require slurp slurp
        require swappy swappy
        geo=$(slurp) || exit 0
        [[ -n $geo ]] || exit 0
        grim -g "$geo" - | swappy -f -
        ;;
    ui)
        require niri "niri compositor"
        niri msg action screenshot --show-pointer false
        ;;
esac
