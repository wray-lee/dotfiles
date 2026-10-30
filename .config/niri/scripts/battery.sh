#!/usr/bin/env bash
# Print the battery charge/state for the lock screen. One job, sysfs only.
set -euo pipefail

for cap in /sys/class/power_supply/BAT*/capacity; do
    [[ -r $cap ]] || continue
    status_file=${cap%/capacity}/status
    status=$(cat "$status_file" 2>/dev/null || printf 'unknown')
    printf 'Battery: %s%% (%s)\n' "$(cat "$cap")" "$status"
done
