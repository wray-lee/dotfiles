#!/usr/bin/env bash
# Regenerate the wallust palette from the current wallpaper (or a theme) and
# reload clients. Single recolor entry point for the niri port.
#
# Usage:
#   wallust.sh                 regenerate from the saved wallpaper, reload clients
#   wallust.sh --from <image>  regenerate from a specific image
#   wallust.sh --theme <name>  apply a built-in wallust theme, reload clients
#   wallust.sh --reload        reload clients only (no palette regeneration)
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

usage() { printf 'usage: %s [--reload] [--from <image>] [--theme <name>]\n' "$0" >&2; }

MODE="run"
IMAGE=""
THEME=""
while (($# > 0)); do
    case "$1" in
        --reload) MODE="reload" ;;
        --from)
            IMAGE=${2:-}
            [[ -n $IMAGE ]] || { usage; exit 2; }
            shift
            ;;
        --theme)
            THEME=${2:-}
            [[ -n $THEME ]] || { usage; exit 2; }
            MODE="theme"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
    shift
done

reload_clients() {
    pkill -SIGUSR2 waybar 2>/dev/null || true
    swaync-client -rs >/dev/null 2>&1 || true
    local -a kitty_pids=()
    mapfile -t kitty_pids < <(pgrep -x kitty 2>/dev/null || true)
    if ((${#kitty_pids[@]} > 0)); then
        kill -SIGUSR1 "${kitty_pids[@]}" 2>/dev/null || true
    fi
}

# hyprlock's `source` file (read by idle/hyprlock.conf):
# $background/$foreground/$color0..15 as rgb(hex). Derived from wallust's
# neutral waybar template output (no Hyprland paths).
write_lock_colors() {
    local css="$HOME/.config/waybar/wallust/colors-waybar.css" tmp
    [[ -f $css ]] || return 0
    mkdir -p "$NIRI_DIR/idle"
    tmp="$NIRI_DIR/idle/colors.conf.tmp"
    awk '
        /@define-color/ {
            name = $2
            hex = $3
            gsub(/;/, "", hex)
            if (name == "foreground" || name == "background" || name ~ /^color[0-9]+$/) {
                sub(/^#/, "", hex)
                printf "$%s = rgb(%s)\n", name, toupper(hex)
            }
        }
    ' "$css" >"$tmp"
    mv "$tmp" "$NIRI_DIR/idle/colors.conf"
}

run_wallust() {
    local img=$1
    if wallust --version 2>/dev/null | grep -qE '^wallust (2|3)\.'; then
        wallust run -s "$img"
    else
        wallust run "$img"
    fi
}

case "$MODE" in
    reload)
        # Reload only: no palette regeneration, but re-derive the lock colors
        # from the (already generated) template output.
        write_lock_colors
        reload_clients
        ;;
    theme)
        require wallust wallust
        wallust theme "$THEME"
        write_lock_colors
        reload_clients
        ;;
    run)
        require wallust wallust
        if [[ -z $IMAGE ]]; then
            if [[ -f $WALLPAPER_STATE ]]; then
                IMAGE=$(readlink -f "$WALLPAPER_STATE" 2>/dev/null || true)
            fi
            if [[ -z $IMAGE || ! -f $IMAGE ]] && [[ -f $ROFI_CURRENT_WALLPAPER ]]; then
                IMAGE=$(readlink -f "$ROFI_CURRENT_WALLPAPER" 2>/dev/null || true)
            fi
        fi
        if [[ -z $IMAGE || ! -f $IMAGE ]]; then
            notify "Wallust" "No wallpaper to read colors from"
            exit 1
        fi
        run_wallust "$IMAGE"
        write_lock_colors
        reload_clients
        ;;
esac
