#!/usr/bin/env bash
# Enable/disable the touchpad at runtime.
#
# niri 26.04 has no `toggle-touchpad` action, so this writes the generated
# include $NIRI_DIR/conf/local/touchpad.kdl (included last in config.kdl).
# niri hot-reloads on write; no restart needed.
# With niri >= 26.05, bind `toggle-touchpad` directly and drop this script.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

CONF="$NIRI_DIR/conf/local/touchpad.kdl"

# Match the generated statement, not the word "off" in the file's comment.
is_disabled() { grep -qE '^[[:space:]]*off;' "$CONF" 2>/dev/null; }

disable_touchpad() {
    mkdir -p "$(dirname -- "$CONF")"
    printf 'input {\n    touchpad {\n        off;\n    }\n}\n' >"$CONF"
    notify "Touchpad" "Disabled"
}

enable_touchpad() {
    mkdir -p "$(dirname -- "$CONF")"
    : >"$CONF"
    notify "Touchpad" "Enabled"
}

case "${1:-toggle}" in
    toggle)
        if is_disabled; then
            enable_touchpad
        else
            disable_touchpad
        fi
        ;;
    on) enable_touchpad ;;
    off) disable_touchpad ;;
    status)
        if is_disabled; then
            printf 'disabled\n'
        else
            printf 'enabled\n'
        fi
        ;;
    *)
        printf 'usage: %s {toggle|on|off|status}\n' "$0" >&2
        exit 2
        ;;
esac
