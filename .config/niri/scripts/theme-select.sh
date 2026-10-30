#!/usr/bin/env bash
# Pick a wallust theme with rofi and apply it. One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require wallust
require rofi

choice=""
if ! choice="$(wallust theme list | sed -e '1d' -e 's/^- //' | rofi -dmenu -i -p 'Select Global Theme')"; then
    exit 0
fi
[[ -n $choice ]] || exit 0

wallust theme -- "$choice"
notify "Global theme changed" "Selected: ${choice}"

# Reload every template consumer (documented sibling CLI).
"$SELF_DIR/wallust.sh" --reload 2>/dev/null || true
