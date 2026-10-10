#!/bin/bash

IME="--ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3"
OZONE="--ozone-platform=wayland --enable-features=UseOzonePlatform"
dst=~/.local/share/applications
mkdir -p "$dst"

# fix <desktop file> <sed commands applied to Exec= lines>
fix() {
    src="/usr/share/applications/$1"
    if [ ! -f "$src" ]; then
        echo "跳过 $1 (未安装)"
        return
    fi
    sed -E "/^Exec=/ { $2 }" "$src" > "$dst/$1"
    echo "已处理 $1"
}

ime="/%[UuFf]/ s/ (%[UuFf])/ $IME \1/; /%[UuFf]/! s/\$/ $IME/"
for f in code bilibili lx-music-desktop linuxqq typora; do fix "$f.desktop" "$ime"; done
fix microsoft-edge-dev.desktop "s|^Exec=([^ ]+)|Exec=\1 $OZONE|"
fix thorium-browser.desktop "s|^Exec=([^ ]+)|Exec=\1 $OZONE|"
fix onlyoffice-desktopeditors.desktop "$ime; s|^Exec=([^ ]+)|Exec=env QT_QPA_PLATFORM=xcb \1 --custom-title-bar|"

update-desktop-database "$dst" 2>/dev/null || true
