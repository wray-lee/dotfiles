#!/usr/bin/env bash
# Rofi wallpaper picker: apply the chosen image to the focused output,
# persist it and recolor clients.
#
# Usage: wallpaper-select.sh [image]
#   With an image argument the picker is skipped and that image is applied.
#   ROFI_WALLPAPER_LINK=0 keeps ~/.config/rofi/.current_wallpaper untouched.
#
# Images only: niri has no live-wallpaper (video) integration here, so video
# files in the wallpaper directory are ignored.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq
require awww awww
require awww-daemon awww
require rofi rofi

WALL_DIR=$(wallpapers_dir)

apply_image() {
    local path=$1 output
    output=$(focused_output_name)
    if [[ -z $output ]]; then
        notify "Wallpaper" "No focused output"
        exit 1
    fi
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
    fi
    for _ in {1..20}; do
        awww query >/dev/null 2>&1 && break
        sleep 0.1
    done
    awww img -o "$output" --transition-fps 90 --transition-type any \
        --transition-duration 1 --transition-bezier .43,1.19,1,.4 "$path"
    mkdir -p "$STATE_DIR"
    ln -sfn "$path" "$WALLPAPER_STATE"
    if [[ ${ROFI_WALLPAPER_LINK:-1} == 1 ]]; then
        ln -sfn "$path" "$ROFI_CURRENT_WALLPAPER"
    fi
}

recolor() {
    if [[ -x "$SELF_DIR/wallust.sh" ]]; then
        exec "$SELF_DIR/wallust.sh" --from "$1"
    fi
}

# Direct mode.
if [[ -n ${1:-} ]]; then
    if [[ ! -f $1 ]]; then
        notify "Wallpaper" "Not a file: $1"
        exit 1
    fi
    apply_image "$1"
    recolor "$1"
    exit 0
fi

if [[ ! -d $WALL_DIR ]]; then
    notify "Wallpaper" "No wallpaper directory: $WALL_DIR"
    exit 1
fi

mapfile -d '' pics < <(find -L "$WALL_DIR" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o \
    -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.webp' \) -print0)

if ((${#pics[@]} == 0)); then
    notify "Wallpaper" "No wallpapers in $WALL_DIR"
    exit 1
fi

current=""
if [[ -f $WALLPAPER_STATE ]]; then
    current=$(readlink -f "$WALLPAPER_STATE" 2>/dev/null || true)
fi
if [[ -z $current || ! -f $current ]] && [[ -f $ROFI_CURRENT_WALLPAPER ]]; then
    current=$(readlink -f "$ROFI_CURRENT_WALLPAPER" 2>/dev/null || true)
fi

random_pic=${pics[RANDOM % ${#pics[@]}]}

declare -A by_name=()
sorted=()
while IFS= read -r pic; do
    sorted+=("$pic")
    by_name["$(basename -- "$pic")"]=$pic
done < <(printf '%s\n' "${pics[@]}" | LC_ALL=C sort)

# Icon size from the focused output, clamped exactly like the original script.
read -r output height scale < <(niri_json focused-output |
    jq -r '[.name, .logical.height, .logical.scale] | @tsv') || true
if [[ -z $output ]]; then
    notify "Wallpaper" "No focused output"
    exit 1
fi
adjusted=$(awk -v h="$height" -v s="$scale" 'BEGIN {
    physical = h * s
    icon = physical * 3 / (s * 150)
    if (icon < 15) icon = 20
    if (icon > 25) icon = 25
    printf "%.0f", icon
}')

theme="$HOME/.config/rofi/config-wallpaper.rasi"
rofi_cmd=(rofi -dmenu -i -config "$theme" -theme-str "element-icon{size:${adjusted}%;}")

menu() {
    printf 'Random: %s\x00icon\x1f%s\n' "$(basename -- "$random_pic")" "$random_pic"
    if [[ -n $current && -f $current ]]; then
        printf 'Current: %s\x00icon\x1f%s\n' "$(basename -- "$current")" "$current"
    fi
    local pic
    for pic in "${sorted[@]}"; do
        printf '%s\x00icon\x1f%s\n' "$(basename -- "$pic")" "$pic"
    done
}

choice=$(menu | "${rofi_cmd[@]}") || exit 0
[[ -n $choice ]] || exit 0

selected=""
if [[ $choice == Random:\ * ]]; then
    selected=$random_pic
elif [[ $choice == Current:\ * ]]; then
    selected=$current
else
    selected=${by_name[$choice]:-}
fi

if [[ -z $selected || ! -f $selected ]]; then
    notify "Wallpaper" "Could not resolve selection"
    exit 1
fi

apply_image "$selected"
recolor "$selected"
