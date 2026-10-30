#!/usr/bin/env bash
# Kill the process owning the focused window.
#
# Usage: kill-window.sh [--graceful]   (default: SIGKILL)
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq

signal="-9"
case "${1:-}" in
    --graceful) signal="-TERM" ;;
    "" | --force) ;;
    *)
        printf 'usage: %s [--graceful]\n' "$0" >&2
        exit 2
        ;;
esac

pid=$(niri_json focused-window | jq -r '.pid // empty')

if [[ -n $pid ]]; then
    kill "$signal" "$pid" 2>/dev/null || niri msg action close-window
else
    niri msg action close-window
fi
