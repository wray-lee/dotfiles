#!/usr/bin/env bash
# Apply an ImageMagick effect to the current wallpaper.
# Requires imagemagick (`magick`). The modified image is temporary; the saved
# wallpaper is unchanged, so it is restored on the next startup.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq
require awww awww
require awww-daemon awww
require rofi rofi
require magick imagemagick

OUT="${TMPDIR:-/tmp}/niri-wallpaper-modified.png"

current=""
if [[ -f $WALLPAPER_STATE ]]; then
    current=$(readlink -f "$WALLPAPER_STATE" 2>/dev/null || true)
fi
if [[ -z $current || ! -f $current ]] && [[ -f $ROFI_CURRENT_WALLPAPER ]]; then
    current=$(readlink -f "$ROFI_CURRENT_WALLPAPER" 2>/dev/null || true)
fi
if [[ -z $current || ! -f $current ]]; then
    notify "Wallpaper effects" "No current wallpaper"
    exit 1
fi

effects=(
    "No Effects"
    "Black & White"
    "Blurred"
    "Charcoal"
    "Edge Detect"
    "Emboss"
    "Frame Raised"
    "Frame Sunk"
    "Negate"
    "Oil Paint"
    "Posterize"
    "Polaroid"
    "Sepia Tone"
    "Solarize"
    "Sharpen"
    "Vignette"
    "Vignette-black"
    "Zoomed"
)

apply_effect() {
    local name=$1 src=$2 dst=$3
    case "$name" in
        "No Effects") return 0 ;;
        "Black & White") magick "$src" -colorspace gray -sigmoidal-contrast 10,40% "PNG:$dst" ;;
        "Blurred") magick "$src" -blur 0x10 "PNG:$dst" ;;
        "Charcoal") magick "$src" -charcoal 0x5 "PNG:$dst" ;;
        "Edge Detect") magick "$src" -edge 1 "PNG:$dst" ;;
        "Emboss") magick "$src" -emboss 0x5 "PNG:$dst" ;;
        "Frame Raised") magick "$src" +raise 150 "PNG:$dst" ;;
        "Frame Sunk") magick "$src" -raise 150 "PNG:$dst" ;;
        "Negate") magick "$src" -negate "PNG:$dst" ;;
        "Oil Paint") magick "$src" -paint 4 "PNG:$dst" ;;
        "Posterize") magick "$src" -posterize 4 "PNG:$dst" ;;
        "Polaroid") magick "$src" -polaroid 0 "PNG:$dst" ;;
        "Sepia Tone") magick "$src" -sepia-tone 65% "PNG:$dst" ;;
        "Solarize") magick "$src" -solarize 80% "PNG:$dst" ;;
        "Sharpen") magick "$src" -sharpen 0x5 "PNG:$dst" ;;
        "Vignette") magick "$src" -vignette 0x3 "PNG:$dst" ;;
        "Vignette-black") magick "$src" -background black -vignette 0x3 "PNG:$dst" ;;
        "Zoomed") magick "$src" -gravity Center -extent 1:1 "PNG:$dst" ;;
        *)
            notify "Wallpaper effects" "Unknown effect: $name"
            exit 1
            ;;
    esac
}

theme="$HOME/.config/rofi/config-wallpaper-effect.rasi"
choice=$(printf '%s\n' "${effects[@]}" | LC_ALL=C sort |
    rofi -dmenu -i -config "$theme") || exit 0
[[ -n $choice ]] || exit 0

applied=$current
if [[ $choice != "No Effects" ]]; then
    apply_effect "$choice" "$current" "$OUT"
    applied=$OUT
fi

output=$(focused_output_name)
if [[ -z $output ]]; then
    notify "Wallpaper effects" "No focused output"
    exit 1
fi

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
fi
for _ in {1..20}; do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
done

awww img -o "$output" --transition-fps 60 --transition-type wipe \
    --transition-duration 2 --transition-bezier .43,1.19,1,.4 "$applied"

if [[ -x "$SELF_DIR/wallust.sh" ]]; then
    "$SELF_DIR/wallust.sh" --from "$applied" || true
fi
