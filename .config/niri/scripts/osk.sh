#!/usr/bin/env bash
# Show, hide or toggle the on-screen keyboard (squeekboard). One job.
#
# Usage: osk.sh show|hide|toggle
#
# fcitx5 owns input-method-v2, so squeekboard never pops up on text focus;
# visibility is driven over its D-Bus interface instead. Called by the waybar
# custom/osk button and by udev/90-osk-keyboard-cover.rules (cover detached ->
# show, attached -> hide).
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require squeekboard
require busctl

osk() { busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 "$@"; }
visible() { busctl get-property --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible 2>/dev/null | grep -q true; }

ensure_running() {
    pgrep -u "$UID" -x squeekboard >/dev/null && return 0
    # taller landscape panel so the 15-column us_wide.yaml keys are not flat
    gsettings set sm.puri.Squeekboard scale-in-horizontal-screen-orientation 1.4 || true
    setsid -f squeekboard >/dev/null 2>&1
    for _ in $(seq 20); do
        busctl --user status sm.puri.OSK0 >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "osk: squeekboard did not register on D-Bus" >&2
    return 1
}

case ${1-} in
    show)   ensure_running && osk SetVisible b true ;;
    hide)   pgrep -u "$UID" -x squeekboard >/dev/null && osk SetVisible b false || true ;;
    toggle) ensure_running && if visible; then osk SetVisible b false; else osk SetVisible b true; fi ;;
    *)      echo "usage: ${0##*/} show|hide|toggle" >&2; exit 2 ;;
esac
