#!/usr/bin/env bash
# Show, hide or toggle the on-screen keyboard (wvkbd). One job.
#
# Usage: osk.sh show|hide|toggle
#
# Called by the waybar custom/osk button, scripts/gestures.sh and
# udev/90-osk-keyboard-cover.rules (cover detached -> show, attached -> hide).
#
# wvkbd sends keys through zwp_virtual_keyboard_v1 and never binds
# input-method-v2 (do NOT pass --auto: that would take the seat from fcitx5
# again). Keys reach fcitx5 like physical ones, so Chinese and the
# keyboard-us-intl dead keys work. Visibility is driven by signals:
# SIGUSR2 show, SIGUSR1 hide, SIGRTMIN toggle.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

# built from the wvkbd 0.21 source with LAYOUT=deskintl; ~/.local/bin is not on PATH
BIN=$HOME/.local/bin/wvkbd-deskintl
NAME=${BIN##*/}
[ -x "$BIN" ] || { echo "osk: $BIN not found" >&2; exit 1; }

running() { pgrep -u "$UID" -x "$NAME" >/dev/null; }
sig() { pkill -u "$UID" -x "$NAME" -"$1"; }

# spawned by niri: a child of this script dies with udev's transient unit.
# Starts visible; callers that only wanted a signal skip it afterwards.
start() {
    niri msg action spawn -- "$BIN" -H 420 -L 360 --fn "Sans 20"
    for _ in $(seq 20); do running && return 0; sleep 0.1; done
    echo "osk: $NAME did not start" >&2
    return 1
}

case ${1-} in
    show)   running && sig USR2 || start ;;
    hide)   running && sig USR1 || true ;;
    toggle) running && sig RTMIN || start ;;
    *)      echo "usage: ${0##*/} show|hide|toggle" >&2; exit 2 ;;
esac
