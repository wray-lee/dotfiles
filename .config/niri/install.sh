#!/usr/bin/env bash
# One-shot setup for the parts of the niri desktop that copying ~/.config cannot do.
# Run after the dotfiles are in place: bash ~/.config/niri/install.sh
set -euo pipefail

NIRI_DIR=$(CDPATH='' cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)

# keyboard cover detach/attach -> show/hide the on-screen keyboard (needs root)
sudo install -m644 "$NIRI_DIR/udev/90-osk-keyboard-cover.rules" /etc/udev/rules.d/
sudo udevadm control --reload

# pick up ~/.config/systemd/user/swaync.service.d/niri.conf without a re-login
systemctl --user daemon-reload
if [[ ${XDG_CURRENT_DESKTOP-} == niri ]]; then
    systemctl --user restart swaync.service
fi

echo "niri install: done"
