#!/usr/bin/env bash
# Toggle floating for every window on the focused workspace.
#
# Usage: float-all.sh {toggle|on|off}
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq

mode="${1:-toggle}"
case "$mode" in
    toggle | on | off) ;;
    *)
        printf 'usage: %s {toggle|on|off}\n' "$0" >&2
        exit 2
        ;;
esac

ws_id=$(niri_json workspaces | jq -r 'first(.[] | select(.is_focused) | .id) // empty')
if [[ -z $ws_id ]]; then
    exit 0
fi

while read -r id floating; do
    [[ -n $id ]] || continue
    case "$mode:$floating" in
        on:true | off:false) continue ;;
    esac
    niri msg action toggle-window-floating --id "$id"
done < <(niri_json windows |
    jq -r --argjson ws "$ws_id" '.[] | select(.workspace_id == $ws) | "\(.id) \(.is_floating)"')
