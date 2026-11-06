if [ -z "${DISPLAY}" ] && [ -z "${WAYLAND_DISPLAY}" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
    # niri wins when both are installed; -l stops niri-session re-running this file
    if command -v niri-session >/dev/null 2>&1; then
        exec niri-session -l
    elif command -v Hyprland >/dev/null 2>&1; then
        Hyprland
    fi
fi
