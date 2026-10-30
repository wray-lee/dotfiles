#!/usr/bin/env bash
# Start awww-daemon if needed and restore the saved wallpaper on every output.
# Intended for spawn-sh-at-startup in conf/startup.kdl.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq
require awww awww
require awww-daemon awww

mkdir -p "$STATE_DIR"

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
fi

for _ in {1..20}; do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
done

# Fallback: awww cache holds the last applied image per output.
cache_wallpaper() {
    local dir f candidate
    for dir in "$HOME/.cache/awww" "$HOME/.cache/swww"; do
        [[ -d $dir ]] || continue
        for f in "$dir"/*; do
            [[ -f $f ]] || continue
            candidate=$(awk 'NF && $0 !~ /^filter/ { print; exit }' "$f")
            if [[ -n $candidate && -f $candidate ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    return 0
}

image=""
if [[ -f $WALLPAPER_STATE ]]; then
    image=$(readlink -f "$WALLPAPER_STATE" 2>/dev/null || printf '%s' "$WALLPAPER_STATE")
fi
if [[ -z $image || ! -f $image ]] && [[ -f $ROFI_CURRENT_WALLPAPER ]]; then
    image=$(readlink -f "$ROFI_CURRENT_WALLPAPER" 2>/dev/null || printf '%s' "$ROFI_CURRENT_WALLPAPER")
fi
if [[ -z $image || ! -f $image ]]; then
    image=$(cache_wallpaper)
fi
if [[ -z $image || ! -f $image ]]; then
    notify "Wallpaper" "No saved wallpaper found"
    exit 0
fi

mapfile -t outputs < <(niri_json outputs | jq -r 'keys[]')
for output in "${outputs[@]}"; do
    awww img -o "$output" --transition-type any --transition-duration 1 "$image" || true
done

if [[ -x "$SELF_DIR/wallust.sh" ]]; then
    "$SELF_DIR/wallust.sh" --reload || true
fi
