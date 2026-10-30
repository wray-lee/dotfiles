#!/usr/bin/env bash
# Apply the lid open/closed output policy.
#
# Triggered by niri's native switch-events (lid-close/lid-open in
# conf/misc.kdl), or by `lid.sh watch` as a polling loop — use one, not both.
# On lid close: if an external monitor is connected, turn the internal panel
# off (with no external monitor logind suspends; hypridle's before_sleep_cmd
# then locks the session). With an external monitor this script does not lock.
# On lid open: turn the internal panel back on.
#
# `niri msg output` changes are temporary: they are forgotten when the output
# config changes or niri restarts. Persistent policy belongs in conf/outputs.kdl.
#
# Usage: lid.sh {close|open|status|watch}
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq

internal_output() {
    if [[ -n ${LID_OUTPUT:-} ]]; then
        printf '%s\n' "$LID_OUTPUT"
        return 0
    fi
    niri_json outputs | jq -r 'first(keys[] | select(test("^(eDP|LVDS)"))) // empty'
}

external_present() {
    local internal=$1
    niri_json outputs |
        jq -r --arg internal "$internal" '[keys[] | select(. != $internal)] | length > 0'
}

do_close() {
    local internal
    internal=$(internal_output)
    if [[ -z $internal ]]; then
        printf 'lid.sh: no internal output found (set LID_OUTPUT)\n' >&2
        return 0
    fi
    if [[ $(external_present "$internal") == true ]]; then
        niri msg output "$internal" off
    fi
}

do_open() {
    local internal
    internal=$(internal_output)
    if [[ -z $internal ]]; then
        printf 'lid.sh: no internal output found (set LID_OUTPUT)\n' >&2
        return 0
    fi
    niri msg output "$internal" on
}

lid_state() {
    local f
    for f in /proc/acpi/button/lid/*/state; do
        [[ -f $f ]] || continue
        awk '{ print $2 }' "$f"
        return 0
    done
    return 1
}

do_watch() {
    local prev="" state
    while :; do
        if ! state=$(lid_state); then
            printf 'lid.sh: no ACPI lid device (/proc/acpi/button/lid)\n' >&2
            exit 1
        fi
        if [[ $state != "$prev" ]]; then
            case "$state" in
                closed) do_close ;;
                open) do_open ;;
            esac
            prev=$state
        fi
        sleep 2
    done
}

ARGS=()
for arg in "$@"; do
    case "$arg" in
        --persist)
            printf 'lid.sh: --persist is not implemented; edit conf/outputs.kdl for a persistent policy\n' >&2
            ;;
        *) ARGS+=("$arg") ;;
    esac
done

case "${ARGS[0]:-}" in
    close) do_close ;;
    open) do_open ;;
    status) niri_json outputs | jq . ;;
    watch) do_watch ;;
    *)
        printf 'usage: %s {close|open|status|watch}\n' "$0" >&2
        exit 2
        ;;
esac
