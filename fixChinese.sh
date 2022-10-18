#!/bin/bash

sed -ie 's/\/usr\/bin\/code %F/\/usr\/bin\/code --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %F/g' /usr/share/applications/code.desktop
sed -ie 's/\/opt\/bilibili-appimage\/bilibili.AppImage --no-sandbox %U/\/opt\/bilibili-appimage\/bilibili.AppImage --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/bilibili.desktop
sed -ie 's/\/opt\/lx-music-desktop\/lx-music-desktop %U/\/opt\/lx-music-desktop\/lx-music-desktop --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/lx-music-desktop.desktop
sed -ie 's/\/usr\/bin\/linuxqq --no-sandbox %U/\/usr\/bin\/linuxqq --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/linuxqq.desktop
