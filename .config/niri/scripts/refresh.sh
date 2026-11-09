#!/usr/bin/env bash
# Restart bar/notification UI and close rofi (post-theme refresh). One job.
set -euo pipefail

SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

pkill -x rofi 2>/dev/null || true

# Notification daemon: restart so it re-reads its config, then reload rules.
if command -v swaync >/dev/null 2>&1; then
    # the unit's drop-in (~/.config/systemd/user/swaync.service.d/niri.conf) picks niri's config
    systemctl --user restart swaync.service 2>/dev/null || true
fi

# Waybar is started by waybar-niri.sh (single owner of its launch command);
# "Laptop" selects the startup variant without opening a picker.
if [[ "${1:-}" != "--no-waybar" ]]; then
    if pgrep -x waybar >/dev/null; then
        pkill -SIGUSR2 waybar 2>/dev/null || true
    elif [[ -x "$SELF_DIR/waybar-niri.sh" ]]; then
        "$SELF_DIR/waybar-niri.sh" Laptop >/dev/null 2>&1 &
    fi
fi
