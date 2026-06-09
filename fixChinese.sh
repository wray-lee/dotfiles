#!/bin/bash

if [ -e "/usr/share/applications/code.desktop" ]; then
  sed -ie 's/\/usr\/bin\/code %F/\/usr\/bin\/code --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %F/g' /usr/share/applications/code.desktop
fi
if [ -e "/usr/share/applications/bilibili.desktop" ]; then
  sed -ie 's/\/opt\/bilibili-appimage\/bilibili.AppImage --no-sandbox %U/\/opt\/bilibili-appimage\/bilibili.AppImage --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/bilibili.desktop
fi
if [ -e "/usr/share/applications/lx-music-desktop.desktop" ]; then
  sed -ie 's/\/opt\/lx-music-desktop\/lx-music-desktop %U/\/opt\/lx-music-desktop\/lx-music-desktop --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/lx-music-desktop.desktop
fi
if [ -e "/usr/share/applications/linuxqq.desktop" ]; then
  sed -ie 's/\/usr\/bin\/linuxqq --no-sandbox %U/\/usr\/bin\/linuxqq --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/linuxqq.desktop
fi
if [ -e "/usr/share/applications/typora.desktop" ]; then
  sed -ie 's/typora %U/typora --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %U/g' /usr/share/applications/typora.desktop
fi
if [ -e "/usr/share/applications/onlyoffice-desktopeditors.desktop" ]; then
  sed -ie 's/\/usr\/bin\/onlyoffice-desktopeditors %F/\/usr\/bin\/onlyoffice-desktopeditors --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3 %F/g' /usr/share/applications/onlyoffice-desktopeditors.desktop
fi
if [ -e "/usr/share/applications/microsoft-edge-dev.desktop" ]; then
  sed -ie 's/\/usr\/bin\/microsoft-edge-dev/\/usr\/bin\/microsoft-edge-dev --ozone-platform=wayland --enable-features=UseOzonePlatform/g' /usr/share/applications/microsoft-edge-dev.desktop
fi
if [ -e "/usr/share/applications/thorium-browser.desktop" ]; then
  sed -ie 's/\/usr\/bin\/thorium-browser/\/usr\/bin\/thorium-browser --ozone-platform=wayland --enable-features=UseOzonePlatform/g' /usr/share/applications/thorium-browser.desktop
fi
if [ -e "/usr/share/applications/onlyoffice-desktopeditors.desktop" ]; then
  sed -ie 's/\/usr\/bin\/onlyoffice-desktopeditors/env QT_QPA_PLATFORM=xcb \/usr\/bin\/onlyoffice-desktopeditors/g' /usr/share/applications/thorium-browser.desktop
fi
