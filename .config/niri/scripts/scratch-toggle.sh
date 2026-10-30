#!/usr/bin/env bash
# Toggle the "scratch" workspace, like Hyprland's togglespecialworkspace.
#
# If "scratch" is focused, go back to the previous workspace; otherwise focus
# "scratch". One job, IPC only (no config parsing).
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source=scripts/lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri "niri compositor"
require jq jq

SCRATCH_WS="scratch"

focused=$(niri_json workspaces |
    jq -r '.[] | select(.is_focused) | .name // empty')

if [[ $focused == "$SCRATCH_WS" ]]; then
    niri msg action focus-workspace-previous
else
    niri msg action focus-workspace "$SCRATCH_WS"
fi
