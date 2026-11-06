#!/usr/bin/env bash
# Hyprland-like column widths on top of niri's scrolling layout. One job.
#
# Whenever the number of tiled columns on a workspace changes:
#   1 column  -> it fills the output (100%)
#   2 columns -> each gets half (like a dwindle split)
#   3+        -> left alone (niri scrolls)
# Acting only on a change of the count means manual resizes are kept.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri
require jq
require flock util-linux

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/niri-autofill.lock"
flock -n 9 || exit 0

# "workspace_id column_count first_window_id_of_each_column..." per workspace
columns() {
    niri_json windows | jq -r '
        map(select((.is_floating | not) and .workspace_id != null))
        | group_by(.workspace_id)[]
        | group_by(.layout.pos_in_scrolling_layout[0]) as $cols
        | "\(.[0].workspace_id) \($cols | length) \($cols | map(.[0].id) | join(" "))"'
}

declare -A last=()

apply() {
    local ws n ids width id
    declare -A seen=()
    while read -r ws n ids; do
        seen[$ws]=1
        [[ ${last[$ws]-} == "$n" ]] && continue
        last[$ws]=$n
        case $n in
            1) width=100% ;;
            2) width=50% ;;
            *) continue ;;
        esac
        for id in $ids; do
            niri msg action set-window-width --id "$id" "$width" || true
        done
    done < <(columns)
    # forget emptied workspaces so their next window is handled again
    for ws in "${!last[@]}"; do
        [[ -n ${seen[$ws]-} ]] || unset 'last[$ws]'
    done
}

apply
niri msg --json event-stream | while read -r event; do
    case $(jq -r 'keys[0]' <<<"$event") in
        WindowOpenedOrChanged | WindowClosed | WindowLayoutsChanged | WindowsChanged) apply ;;
    esac
done
