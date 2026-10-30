#!/usr/bin/env bash
# Pick a random wallpaper, apply it to the focused output and recolor.
#
# Usage: wallpaper-random.sh [dir]   (default: <Pictures>/wallpapers)
# Rotation: point a systemd user timer at this script.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

dir="${1:-$(wallpapers_dir)}"

if [[ ! -d $dir ]]; then
    notify "Wallpaper" "No wallpaper directory: $dir"
    exit 1
fi

picked=$(find "$dir" -maxdepth 1 -type f \( \
    -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)

if [[ -z $picked ]]; then
    notify "Wallpaper" "No wallpapers in $dir"
    exit 1
fi

exec "$SELF_DIR/wallpaper-select.sh" "$picked"
