#!/usr/bin/env bash
# Keyboard backlight control with notification. One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require brightnessctl

iDIR="$HOME/.config/swaync/icons"
kbd_device='*::kbd_backlight'

# Get keyboard brightness
get_kbd_backlight() {
    brightnessctl -d "$kbd_device" -m | cut -d, -f4
}

# Get icons
get_icon() {
    current=$(get_kbd_backlight | tr -d '%')
    if   (( current <= 20 )); then
        icon="$iDIR/brightness-20.png"
    elif (( current <= 40 )); then
        icon="$iDIR/brightness-40.png"
    elif (( current <= 60 )); then
        icon="$iDIR/brightness-60.png"
    elif (( current <= 80 )); then
        icon="$iDIR/brightness-80.png"
    else
        icon="$iDIR/brightness-100.png"
    fi
}

# Notify
notify_user() {
    notify-send -e -h string:x-canonical-private-synchronous:brightness_notif \
        -h int:value:"$current" -h boolean:SWAYNC_BYPASS_DND:true -u low \
        -i "$icon" "Keyboard" "Brightness:${current}%"
}

# Change brightness
change_kbd_backlight() {
    brightnessctl -d "$kbd_device" set "$1" && get_icon && notify_user
}

# Execute accordingly
case "${1:-}" in
    "--get")
        get_kbd_backlight
        ;;
    "--inc")
        change_kbd_backlight "+30%"
        ;;
    "--dec")
        change_kbd_backlight "30%-"
        ;;
    *)
        get_kbd_backlight
        ;;
esac
