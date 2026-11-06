#!/usr/bin/env bash
# Panel refresh rate follows the power profile. One job.
#
#   power-saver           -> 60 Hz
#   balanced/performance  -> 120 Hz
#
# tlp-pd and power-profiles-daemon both serve net.hadess.PowerProfiles, so
# `tlpctl set`, `powerprofilesctl set` and the waybar module all land here.
# `niri msg output` changes are temporary: an edit to the output block in
# conf/outputs.kdl puts its mode back until the next profile change.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

require niri
require busctl systemd
require gdbus glib2
require flock util-linux

# conf/outputs.kdl owns the panel (documented duplicate, as in gestures.sh).
PANEL=eDP-1
SAVER_MODE=2880x1800@60.000
FAST_MODE=2880x1800@120.000

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/niri-refresh-rate.lock"
flock -n 9 || exit 0

apply() {
    local profile mode=$FAST_MODE
    # no profile daemon: leave the mode from conf/outputs.kdl alone
    profile=$(busctl --system get-property net.hadess.PowerProfiles \
        /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile) || return 0
    [[ $profile == *'"power-saver"'* ]] && mode=$SAVER_MODE
    niri msg output "$PANEL" mode "$mode" || true
}

apply
gdbus monitor --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles |
    while read -r line; do
        if [[ $line == *ActiveProfile* ]]; then apply; fi
    done
