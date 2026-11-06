#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
for i in {0..3}; do
  if [ -f /sys/class/power_supply/BAT$i/capacity ]; then
    battery_level=$(cat /sys/class/power_supply/BAT$i/status)
    battery_capacity=$(cat /sys/class/power_supply/BAT$i/capacity)
    echo "Battery: $battery_capacity% ($battery_level)"
  fi
done
