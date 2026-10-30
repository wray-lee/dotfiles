#!/usr/bin/env bash
# Lock the session.
#
# Single owner of locker + config path: Mod+L, the bar lock button and
# hypridle's `lock_cmd` all call this script. The config is
# idle/hyprlock.conf (next to hypridle.conf); its colours are
# idle/colors.conf, written by scripts/wallust.sh.
# Calling `loginctl lock-session` from here would make hypridle re-enter this
# script, so the script runs the locker directly.
#
# Locker selection: $LOCKER, then hyprlock, gtklock, swaylock.
set -euo pipefail
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

locker_cmd=()
if [[ -n ${LOCKER:-} ]]; then
    read -r -a locker_cmd <<<"$LOCKER"
elif command -v hyprlock >/dev/null 2>&1; then
    locker_cmd=(hyprlock -c "$NIRI_DIR/idle/hyprlock.conf")
elif command -v gtklock >/dev/null 2>&1; then
    locker_cmd=(gtklock)
elif command -v swaylock >/dev/null 2>&1; then
    locker_cmd=(swaylock -f)
else
    notify "Lock" "No screen locker installed (hyprlock/gtklock/swaylock)"
    printf 'no screen locker installed\n' >&2
    exit 1
fi

# Best-effort weather refresh for the lock screen; never blocks locking.
if [[ -f "$NIRI_DIR/scripts/weather.py" ]] && command -v python3 >/dev/null 2>&1; then
    python3 "$NIRI_DIR/scripts/weather.py" >/dev/null 2>&1 || true
fi

# Do not stack a second locker if one is already running.
if pgrep -x "${locker_cmd[0]}" >/dev/null 2>&1; then
    exit 0
fi

exec "${locker_cmd[@]}"
