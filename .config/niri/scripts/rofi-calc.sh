#!/usr/bin/env bash
# Calculator (qalc) in rofi; the result is copied to the clipboard. One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require rofi
require qalc
require wl-copy

rofi_theme="$HOME/.config/rofi/config-calc.rasi"

# Kill rofi if already running before execution
if pgrep -x rofi >/dev/null; then
    pkill -x rofi
fi

calc_result=""
result=""
while true; do
    if ! result=$(rofi -i -dmenu -config "$rofi_theme" -mesg "$result      =    $calc_result"); then
        exit 0
    fi

    if [[ -n $result ]]; then
        calc_result=$(qalc -t "$result" || true)
        printf '%s\n' "$calc_result" | wl-copy
    fi
done
