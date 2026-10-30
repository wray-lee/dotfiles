#!/usr/bin/env bash
# Launch or switch the niri-specific waybar variant. One job: pick and run waybar.
#
# Usage:
#   waybar-niri.sh                 run the default niri config, no picker
#   waybar-niri.sh <name>          run "[TOP] Niri <name>", no picker
#   waybar-niri.sh --layout        rofi picker over the niri configs
#   waybar-niri.sh --style         rofi picker over the shared styles
#
# Startup and refresh.sh call it with "Laptop", so no picker ever opens in the
# background. The shared waybar/config and style.css symlinks are never
# rewritten: a style chosen here is remembered in $STATE_DIR/waybar-style.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
CONFIG_DIR="$WAYBAR_DIR/configs"
STYLE_DIR="$WAYBAR_DIR/style"
STYLE_STATE="$STATE_DIR/waybar-style"

mapfile -t configs < <(find "$CONFIG_DIR" -maxdepth 1 -type f -name '[[]TOP[]] Niri*' 2>/dev/null | sort)
mapfile -t niri_styles < <(find "$STYLE_DIR" -maxdepth 1 -type f -name '*Niri*' 2>/dev/null | sort)
mapfile -t all_styles < <(find "$STYLE_DIR" -maxdepth 1 -type f -name '*.css' 2>/dev/null | sort)

pick_config() {
    local interactive=$1 name=${2:-} cfg

    if [[ -n $name ]]; then
        for cfg in "${configs[@]}"; do
            if [[ ${cfg##*/} == "$name" || ${cfg##*/} == "[TOP] Niri $name" ]]; then
                printf '%s\n' "$cfg"
                return 0
            fi
        done
        return 1
    fi

    if [[ $interactive == false ]]; then
        if ((${#configs[@]} > 0)); then
            printf '%s\n' "${configs[0]}"
        elif [[ -r "$WAYBAR_DIR/config-niri" ]]; then
            printf '%s\n' "$WAYBAR_DIR/config-niri"
        else
            return 1
        fi
        return 0
    fi

    require rofi
    local choice
    choice="$(printf '%s\n' "${configs[@]##*/}" | rofi -dmenu -i -p 'Waybar layout')" || return 1
    [[ -n $choice ]] || return 1
    printf '%s\n' "$CONFIG_DIR/$choice"
}

# Default style: remembered choice, else a *Niri* variant, else the shared
# style.css (hyprland and niri then look identical).
default_style() {
    local cfg=$1 variant style

    if [[ -r $STYLE_STATE ]]; then
        style=$(<"$STYLE_STATE")
        [[ -r $style ]] && { printf '%s\n' "$style"; return 0; }
    fi

    if ((${#niri_styles[@]} == 1)); then
        printf '%s\n' "${niri_styles[0]}"
        return 0
    fi

    variant=${cfg##*/}
    variant=${variant#"[TOP] Niri "}
    for style in "${niri_styles[@]}"; do
        [[ ${style##*/} == *"$variant"* ]] && { printf '%s\n' "$style"; return 0; }
    done

    [[ -r "$WAYBAR_DIR/style.css" ]] && printf '%s\n' "$WAYBAR_DIR/style.css"
    return 0
}

pick_style() {
    require rofi
    local choice
    choice="$(printf '%s\n' "${all_styles[@]##*/}" | rofi -dmenu -i -p 'Waybar style')" || return 1
    [[ -n $choice ]] || return 1
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$STYLE_DIR/$choice" >"$STYLE_STATE"
    printf '%s\n' "$STYLE_DIR/$choice"
}

mode="run"
name=""
case "${1:-}" in
    --layout) mode="layout" ;;
    --style) mode="style" ;;
    "") ;;
    -h | --help)
        sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *) name=$1 ;;
esac

interactive=false
if [[ $mode == layout ]]; then
    interactive=true
fi

cfg=$(pick_config "$interactive" "$name") || {
    printf 'waybar-niri: no niri waybar config found under %s\n' "$CONFIG_DIR" >&2
    exit 1
}

if [[ $mode == style ]]; then
    style=$(pick_style) || exit 1
else
    style=$(default_style "$cfg")
fi

pkill -x waybar 2>/dev/null || true
for _ in {1..50}; do
    pgrep -x waybar >/dev/null || break
    sleep 0.02
done

if [[ -n $style ]]; then
    exec waybar -c "$cfg" -s "$style" >/dev/null 2>&1
fi
exec waybar -c "$cfg" >/dev/null 2>&1
