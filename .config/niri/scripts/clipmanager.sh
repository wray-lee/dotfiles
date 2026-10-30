#!/usr/bin/env bash
# Clipboard history browser (cliphist + rofi). One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require cliphist
require rofi
require wl-copy

rofi_theme="$HOME/.config/rofi/config-clipboard.rasi"
msg='👀 **note**  CTRL DEL = cliphist del (entry)   or   ALT DEL - cliphist wipe (all)'

if pgrep -x rofi >/dev/null; then
    pkill -x rofi 2>/dev/null || true
fi

while true; do
    # rofi returns 1 on cancel; that must not abort the loop under errexit.
    set +e
    result="$(rofi -i -dmenu \
        -kb-custom-1 "Control-Delete" \
        -kb-custom-2 "Alt-Delete" \
        -config "$rofi_theme" \
        -mesg "$msg" < <(cliphist list))"
    status=$?
    set -e

    case "$status" in
        1)
            exit 0
            ;;
        0)
            case "$result" in
                "")
                    continue
                    ;;
                *)
                    cliphist decode <<<"$result" | wl-copy
                    exit 0
                    ;;
            esac
            ;;
        10)
            cliphist delete <<<"$result"
            ;;
        11)
            cliphist wipe
            ;;
        *)
            exit "$status"
            ;;
    esac
done
