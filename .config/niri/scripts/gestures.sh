#!/usr/bin/env bash
# Touchscreen gestures via lisgd (niri has no configurable touch gestures).
# One job: find the touchscreen and run lisgd with the gesture table below.
#
#   3 fingers up / down        show / hide the on-screen keyboard
#   3 fingers left / right     focus the column to the right / left
#   4 fingers up               toggle the overview
#   1 finger from top edge     open the notification centre (swaync)
#   1 finger from bottom edge  app launcher (rofi)
#
# lisgd reads the evdev node directly; udev/70-touchscreen-uaccess.rules gives
# the logged-in user access to it. Touches still reach niri and apps as usual.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require lisgd
require udevadm
require jq

# conf/input.kdl maps touch to this output (documented duplicate, as
# screenshots_dir in lib/common.sh); edge zones and distances use its size.
TOUCH_OUTPUT=eDP-1

device=
for ev in /dev/input/event*; do
    if udevadm info -q property "$ev" | grep -qx 'ID_INPUT_TOUCHSCREEN=1'; then
        device=$ev
        break
    fi
done
[[ -n $device ]] || { echo "gestures: no touchscreen found" >&2; exit 0; }

read -r w h < <(niri_json outputs | jq -r --arg o "$TOUCH_OUTPUT" '.[$o].logical | "\(.width) \(.height)"')

osk="bash $SELF_DIR/osk.sh"
act="niri msg action"

pkill -u "$UID" -x lisgd 2>/dev/null || true
# lisgd runs commands with system(), which blocks gesture handling until the
# command exits, hence the trailing & on the long-lived rofi.
exec lisgd -d "$device" -w "$w" -h "$h" \
    -g "3,DU,*,*,R,$osk show" \
    -g "3,UD,*,*,R,$osk hide" \
    -g "3,RL,*,*,R,$act focus-column-right" \
    -g "3,LR,*,*,R,$act focus-column-left" \
    -g "4,DU,*,*,R,$act toggle-overview" \
    -g "1,UD,T,*,R,swaync-client -t -sw" \
    -g "1,DU,B,*,R,{ pkill rofi || rofi -show drun; } >/dev/null 2>&1 &"
