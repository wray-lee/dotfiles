#!/usr/bin/env bash
# Blue-light filter (colour temperature) toggle for niri.
#
# Backend: wlsunset (niri implements zwlr_gamma_control_manager_v1), with
# gammastep as an alternative if wlsunset is not installed.
#   NIGHTLIGHT_TEMP       default 4500 K
#   NIGHTLIGHT_ICON_MODE  sunset|blue (default sunset)
#
# Usage: nightlight.sh {toggle|on|off|status|init|set <K>}
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

STATE_FILE="$STATE_DIR/nightlight"
TEMP_FILE="$STATE_DIR/nightlight-temp"
DEFAULT_TEMP="${NIGHTLIGHT_TEMP:-4500}"
ICON_MODE="${NIGHTLIGHT_ICON_MODE:-sunset}"

mkdir -p "$STATE_DIR"

saved_temp() {
    if [[ -s $TEMP_FILE ]]; then
        cat "$TEMP_FILE"
    else
        printf '%s\n' "$DEFAULT_TEMP"
    fi
}

is_on() { pgrep -x wlsunset >/dev/null 2>&1 || pgrep -x gammastep >/dev/null 2>&1; }

stop_filter() {
    pkill -x wlsunset 2>/dev/null || true
    pkill -x gammastep 2>/dev/null || true
}

start_filter() {
    local temp=$1
    stop_filter
    if command -v wlsunset >/dev/null 2>&1; then
        wlsunset -T "$temp" -t "$temp" >/dev/null 2>&1 &
    elif command -v gammastep >/dev/null 2>&1; then
        gammastep -P -O "$temp" >/dev/null 2>&1 &
    else
        require wlsunset "Night light"
    fi
    sleep 0.3
}

set_on() {
    local temp
    temp=${1:-$(saved_temp)}
    start_filter "$temp"
    printf 'on\n' >"$STATE_FILE"
    printf '%s\n' "$temp" >"$TEMP_FILE"
    notify "Night light" "Enabled at ${temp}K"
}

set_off() {
    stop_filter
    printf 'off\n' >"$STATE_FILE"
    notify "Night light" "Disabled"
}

icon() {
    if [[ "$1" == on ]]; then
        case "$ICON_MODE" in
            sunset) printf '🌇' ;;
            *) printf '☀' ;;
        esac
    else
        printf '☀'
    fi
}

cmd_status() {
    local state class tooltip text
    if is_on; then
        state=on
    elif [[ -f $STATE_FILE ]]; then
        state=$(<"$STATE_FILE")
    else
        state=off
    fi
    if [[ $state == on ]]; then
        class=on
        tooltip="Night light on @ $(saved_temp)K"
    else
        class=off
        tooltip="Night light off"
    fi
    text="<span size='18pt'>$(icon "$state")</span>"
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tooltip"
}

case "${1:-}" in
    toggle)
        state=off
        if [[ -f $STATE_FILE ]]; then
            state=$(<"$STATE_FILE")
        fi
        if is_on || [[ $state == on ]]; then
            set_off
        else
            set_on
        fi
        ;;
    on) set_on ;;
    off) set_off ;;
    init)
        if [[ -f $STATE_FILE && $(<"$STATE_FILE") == on ]]; then
            set_on "$(saved_temp)"
        else
            stop_filter
        fi
        ;;
    set)
        temp=${2:-}
        if [[ ! $temp =~ ^[0-9]+$ ]]; then
            printf 'usage: %s set <kelvin>\n' "$0" >&2
            exit 2
        fi
        set_on "$temp"
        ;;
    status) cmd_status ;;
    *)
        printf 'usage: %s {toggle|on|off|status|init|set <K>}\n' "$0" >&2
        exit 2
        ;;
esac
