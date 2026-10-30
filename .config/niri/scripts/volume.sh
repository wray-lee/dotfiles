#!/usr/bin/env bash
# Volume and microphone control with OSD notifications. One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require pamixer

iDIR="$HOME/.config/swaync/icons"

# Get Volume
get_volume() {
    if [[ "$(pamixer --get-mute)" == "true" ]]; then
        echo "Muted"
        return
    fi

    local volume
    volume=$(pamixer --get-volume)
    if [[ "$volume" -eq 0 ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

# Get icons
get_icon() {
    if [[ "$(pamixer --get-mute)" == "true" ]]; then
        echo "$iDIR/volume-mute.png"
        return
    fi

    local current
    current=$(pamixer --get-volume)
    if [[ "$current" -le 30 ]]; then
        echo "$iDIR/volume-low.png"
    elif [[ "$current" -le 60 ]]; then
        echo "$iDIR/volume-mid.png"
    else
        echo "$iDIR/volume-high.png"
    fi
}

# Notify
notify_user() {
    local muted level
    muted=$(pamixer --get-mute)
    level=$(pamixer --get-volume)

    if [[ "$muted" == "true" || "$level" -eq 0 ]]; then
        notify-send -e -h string:x-canonical-private-synchronous:volume_notif \
            -h boolean:SWAYNC_BYPASS_DND:true -u low -i "$(get_icon)" \
            " Volume:" " Muted"
    else
        notify-send -e -h int:value:"$level" -h string:x-canonical-private-synchronous:volume_notif \
            -h boolean:SWAYNC_BYPASS_DND:true -u low -i "$(get_icon)" \
            " Volume Level:" " ${level}%" &&
            "$SELF_DIR/sounds.sh" --volume 2>/dev/null || true
    fi
}

# Increase Volume
inc_volume() {
    if [[ "$(pamixer --get-mute)" == "true" ]]; then
        toggle_mute
    else
        pamixer -i "$1" --allow-boost --set-limit 150 && notify_user
    fi
}

# Decrease Volume
dec_volume() {
    if [[ "$(pamixer --get-mute)" == "true" ]]; then
        toggle_mute
    else
        pamixer -d "$1" && notify_user
    fi
}

# Toggle Mute
toggle_mute() {
    if [[ "$(pamixer --get-mute)" == "false" ]]; then
        pamixer -m && notify-send -e -u low -h boolean:SWAYNC_BYPASS_DND:true \
            -i "$iDIR/volume-mute.png" " Mute"
    elif [[ "$(pamixer --get-mute)" == "true" ]]; then
        pamixer -u && notify-send -e -u low -h boolean:SWAYNC_BYPASS_DND:true \
            -i "$(get_icon)" " Volume:" " Switched ON"
    fi
}

# Toggle Mic
toggle_mic() {
    if [[ "$(pamixer --default-source --get-mute)" == "false" ]]; then
        pamixer --default-source -m && notify-send -e -u low \
            -h boolean:SWAYNC_BYPASS_DND:true -i "$iDIR/microphone-mute.png" \
            " Microphone:" " Switched OFF"
    elif [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
        pamixer --default-source -u && notify-send -e -u low \
            -h boolean:SWAYNC_BYPASS_DND:true -i "$iDIR/microphone.png" \
            " Microphone:" " Switched ON"
    fi
}

# Get Mic Icon
get_mic_icon() {
    local muted current
    muted=$(pamixer --default-source --get-mute)
    current=$(pamixer --default-source --get-volume)
    if [[ "$muted" == "true" || "$current" -eq 0 ]]; then
        echo "$iDIR/microphone-mute.png"
    else
        echo "$iDIR/microphone.png"
    fi
}

# Get Microphone Volume
get_mic_volume() {
    if [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
        echo "Muted"
        return
    fi

    local volume
    volume=$(pamixer --default-source --get-volume)
    if [[ "$volume" -eq 0 ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

# Notify for Microphone
notify_mic_user() {
    local muted level icon
    muted=$(pamixer --default-source --get-mute)
    level=$(pamixer --default-source --get-volume)

    if [[ "$muted" == "true" || "$level" -eq 0 ]]; then
        icon="$iDIR/microphone-mute.png"
        notify-send -e -h string:x-canonical-private-synchronous:volume_notif \
            -h boolean:SWAYNC_BYPASS_DND:true -u low -i "$icon" \
            " Mic Level:" " Muted"
    else
        icon="$iDIR/microphone.png"
        notify-send -e -h int:value:"$level" -h string:x-canonical-private-synchronous:volume_notif \
            -h boolean:SWAYNC_BYPASS_DND:true -u low -i "$icon" \
            " Mic Level:" " ${level}%"
    fi
}

# Increase MIC Volume
inc_mic_volume() {
    if [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
        toggle_mic
    else
        pamixer --default-source -i 5 && notify_mic_user
    fi
}

# Decrease MIC Volume
dec_mic_volume() {
    if [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
        toggle_mic
    else
        pamixer --default-source -d 5 && notify_mic_user
    fi
}

# Execute accordingly
case "${1:-}" in
    "--get")
        get_volume
        ;;
    "--inc")
        inc_volume 5
        ;;
    "--inc-precise")
        inc_volume 1
        ;;
    "--dec")
        dec_volume 5
        ;;
    "--dec-precise")
        dec_volume 1
        ;;
    "--toggle")
        toggle_mute
        ;;
    "--toggle-mic")
        toggle_mic
        ;;
    "--get-icon")
        get_icon
        ;;
    "--get-mic-icon")
        get_mic_icon
        ;;
    "--mic-inc")
        inc_mic_volume
        ;;
    "--mic-dec")
        dec_mic_volume
        ;;
    *)
        get_volume
        ;;
esac
