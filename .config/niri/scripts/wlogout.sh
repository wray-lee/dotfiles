#!/usr/bin/env bash
# Toggle wlogout, with margins sized from the focused output's logical height.
#
# Uses the niri-only layout/style in idle/ (next to hypridle.conf) so the
# existing ~/.config/wlogout files stay untouched.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq
require wlogout wlogout

if pgrep -x wlogout >/dev/null 2>&1; then
    pkill -x wlogout
    exit 0
fi

read -r name height scale < <(niri_json focused-output |
    jq -r '[.name, .logical.height, .logical.scale] | @tsv') || true
if [[ -z $name ]]; then
    notify "wlogout" "No focused output"
    exit 1
fi

# Margin value for a 2160/1600/1440/1080/720p reference at this scale.
margin() {
    local ref=$1 base=$2
    awk -v r="$height" -v s="$scale" -v ref="$ref" -v base="$base" \
        'BEGIN { printf "%.0f", base * ref * s / r }'
}

rows=6
if awk -v r="$height" 'BEGIN { exit !(r >= 2160) }'; then
    top=$(margin 2160 600)
    bottom=$(margin 2160 600)
elif awk -v r="$height" 'BEGIN { exit !(r >= 1600) }'; then
    top=$(margin 1600 400)
    bottom=$(margin 1600 400)
elif awk -v r="$height" 'BEGIN { exit !(r >= 1440) }'; then
    top=$(margin 1440 400)
    bottom=$(margin 1440 400)
elif awk -v r="$height" 'BEGIN { exit !(r >= 1080) }'; then
    top=$(margin 1080 200)
    bottom=$(margin 1080 200)
elif awk -v r="$height" 'BEGIN { exit !(r >= 720) }'; then
    top=$(margin 720 50)
    bottom=$(margin 720 50)
    rows=3
else
    top=50
    bottom=50
    rows=3
fi

wlogout --protocol layer-shell -b "$rows" -T "$top" -B "$bottom" \
    -l "$NIRI_DIR/idle/wlogout.layout" -C "$NIRI_DIR/idle/wlogout.css"
