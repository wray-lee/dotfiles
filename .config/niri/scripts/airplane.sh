#!/usr/bin/env bash
# Toggle airplane mode (block/unblock wifi via rfkill). One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require rfkill

notif="$HOME/.config/swaync/images/ja.png"

# Check if any wireless device is blocked
wifi_blocked=$(rfkill list wifi | grep -o "Soft blocked: yes" || true)

if [ -n "$wifi_blocked" ]; then
    rfkill unblock wifi
    notify-send -u low -i "$notif" " Airplane" " mode: OFF"
else
    rfkill block wifi
    notify-send -u low -i "$notif" " Airplane" " mode: ON"
fi
