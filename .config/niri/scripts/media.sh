#!/usr/bin/env bash
# Media transport notifications via playerctl. One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require playerctl

music_icon="$HOME/.config/swaync/icons/music.png"

# Play the next track
play_next() {
    playerctl next
    show_music_notification
}

# Play the previous track
play_previous() {
    playerctl previous
    show_music_notification
}

# Toggle play/pause
toggle_play_pause() {
    playerctl play-pause
    sleep 0.1
    show_music_notification
}

# Stop playback
stop_playback() {
    playerctl stop
    notify-send -e -u low -i "$music_icon" " Playback:" " Stopped"
}

# Display notification with song information
show_music_notification() {
    local status title artist
    status=$(playerctl status 2>/dev/null || true)
    if [[ "$status" == "Playing" ]]; then
        title=$(playerctl metadata title 2>/dev/null || true)
        artist=$(playerctl metadata artist 2>/dev/null || true)
        notify-send -e -u low -i "$music_icon" "Now Playing:" "$title by $artist"
    elif [[ "$status" == "Paused" ]]; then
        notify-send -e -u low -i "$music_icon" " Playback:" " Paused"
    fi
}

# Get media control action from command line argument
case "${1:-}" in
    "--nxt")
        play_next
        ;;
    "--prv")
        play_previous
        ;;
    "--pause")
        toggle_play_pause
        ;;
    "--stop")
        stop_playback
        ;;
    *)
        echo "Usage: $0 [--nxt|--prv|--pause|--stop]"
        exit 1
        ;;
esac
