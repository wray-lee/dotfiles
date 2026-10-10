#!/bin/sh
# One-click dotfiles setup for Arch / Debian / Ubuntu / Fedora / Alpine / Termux.
# POSIX sh: runs under dash, busybox ash and Termux sh.
set -eu

RAW=https://raw.githubusercontent.com/wray-lee/dotfiles/main
CODEDARK=https://raw.githubusercontent.com/tomasiser/vim-code-dark/master/colors/codedark.vim
OMZ_INSTALL=https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh

# ---------------------------------------------------------------- platform
OS=
if [ -n "${PREFIX:-}" ]; then
    case "$PREFIX" in
        *com.termux*) OS=termux ;;
    esac
fi
if [ -z "$OS" ] && [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
        arch|manjaro|endeavouros) OS=arch ;;
        ubuntu) OS=ubuntu ;;
        debian) OS=debian ;;
        fedora) OS=fedora ;;
        alpine) OS=alpine ;;
    esac
    if [ -z "$OS" ]; then
        case "${ID_LIKE:-}" in
            *arch*) OS=arch ;;
            *ubuntu*) OS=ubuntu ;;
            *debian*) OS=debian ;;
            *fedora*) OS=fedora ;;
            *alpine*) OS=alpine ;;
        esac
    fi
fi
if [ -z "$OS" ]; then
    echo "Unsupported platform. Aborting." >&2
    exit 1
fi
echo "Detected platform: $OS"

# ---------------------------------------------------------------- privilege
if [ "$OS" = termux ] || [ "$(id -u)" = 0 ]; then
    SUDO=
elif command -v sudo >/dev/null 2>&1; then
    SUDO=sudo
elif command -v doas >/dev/null 2>&1; then
    SUDO=doas
else
    echo "Need root, sudo or doas. Aborting." >&2
    exit 1
fi

# ---------------------------------------------------------------- helpers
# ask "prompt" [y|n]  -> returns 0 on yes (default is the 2nd arg, or n)
ask() {
    _def=${2:-n}
    if [ "$_def" = y ]; then
        printf '%s [Y/n] ' "$1"
    else
        printf '%s [y/N] ' "$1"
    fi
    _ans=
    read -r _ans </dev/tty 2>/dev/null || _ans=
    [ -n "$_ans" ] || _ans=$_def
    case "$_ans" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# pm_install pkg...  (installs the given packages with the native manager)
pm_install() {
    case "$OS" in
        arch)          $SUDO pacman -Syu --needed --noconfirm "$@" ;;
        debian|ubuntu) $SUDO apt-get install -y "$@" ;;
        fedora)        $SUDO dnf install -y "$@" ;;
        alpine)        $SUDO apk add "$@" ;;
        termux)        pkg install -y "$@" ;;
    esac
}

# ---------------------------------------------------------------- mirrors
if ask "Switch to China mirror (USTC)? "; then
    case "$OS" in
        debian)
            for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources; do
                if [ -f "$f" ]; then
                    $SUDO sed -i.bak \
                        -e 's|deb.debian.org|mirrors.ustc.edu.cn|g' \
                        -e 's|security.debian.org|mirrors.ustc.edu.cn|g' "$f"
                fi
            done
            ;;
        ubuntu)
            for f in /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; do
                if [ -f "$f" ]; then
                    $SUDO sed -i.bak \
                        -e 's|//[a-z0-9.-]*archive\.ubuntu\.com|//mirrors.ustc.edu.cn|g' \
                        -e 's|//security\.ubuntu\.com|//mirrors.ustc.edu.cn|g' "$f"
                fi
            done
            ;;
        fedora)
            for f in /etc/yum.repos.d/fedora*.repo; do
                if [ -f "$f" ]; then
                    $SUDO sed -i.bak \
                        -e 's|^metalink=|#metalink=|g' \
                        -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' "$f"
                fi
            done
            ;;
        alpine)
            if [ -f /etc/apk/repositories ]; then
                $SUDO sed -i.bak 's|dl-cdn.alpinelinux.org|mirrors.ustc.edu.cn|g' /etc/apk/repositories
            fi
            ;;
        termux)
            echo "Termux: run 'termux-change-repo' manually to switch mirrors."
            ;;
        arch)
            # skip: mirrorlist is best left to reflector / manual editing
            ;;
    esac
fi

# ---------------------------------------------------------------- packages
case "$OS" in
    arch)          CORE="zsh git curl vim" ;;
    debian|ubuntu) CORE="zsh git curl vim" ;;
    fedora)        CORE="zsh git curl vim" ;;
    alpine)        CORE="zsh git curl vim shadow" ;;
    termux)        CORE="zsh git curl vim which" ;;
esac

case "$OS" in
    arch)          EXTRAS="fastfetch docker nginx ranger bat tldr lsd duf zoxide fd btop nmap fzf" ;;
    debian|ubuntu) EXTRAS="fastfetch docker.io nginx ranger bat tldr lsd duf zoxide fd-find btop nmap fzf" ;;
    fedora)        EXTRAS="fastfetch moby-engine nginx ranger bat tldr lsd duf zoxide fd-find btop nmap fzf" ;;
    alpine)        EXTRAS="fastfetch docker nginx ranger bat tldr lsd duf zoxide fd btop nmap fzf procps iproute2 coreutils" ;;
    termux)        EXTRAS="fastfetch zoxide lsd bat fzf" ;;
esac

case "$OS" in
    debian|ubuntu) $SUDO apt-get update ;;
    alpine)        $SUDO apk update ;;
    termux)        pkg update -y || true ;;
esac

echo "Installing core packages: $CORE"
# shellcheck disable=SC2086
pm_install $CORE

echo "Installing extra packages (best effort)..."
# shellcheck disable=SC2086
if ! pm_install $EXTRAS; then
    echo "Bulk install failed, retrying one by one..."
    for p in $EXTRAS; do
        pm_install "$p" || echo "  skipped: $p"
    done
fi

if [ "$OS" = alpine ]; then
    $SUDO sh -c 'printf "net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=cake\n" > /etc/sysctl.d/99-bbr.conf'
    $SUDO sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------- oh-my-zsh
export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    _omz=$(curl -fsSL "$OMZ_INSTALL")
    RUNZSH=no CHSH=no sh -c "$_omz" "" --unattended
fi

[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# ---------------------------------------------------------------- ~/.zshrc
if [ -f "$HOME/.zshrc" ]; then
    sed -i \
        -e 's|ZSH_THEME="robbyrussell"|ZSH_THEME="powerlevel10k/powerlevel10k"|' \
        -e 's|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|' \
        "$HOME/.zshrc"
    if command -v fastfetch >/dev/null 2>&1 && ! head -n1 "$HOME/.zshrc" | grep -q '^fastfetch'; then
        { printf 'fastfetch\n'; cat "$HOME/.zshrc"; } > "$HOME/.zshrc.tmp"
        mv "$HOME/.zshrc.tmp" "$HOME/.zshrc"
    fi
fi

# ---------------------------------------------------------------- dotfiles
mkdir -p "$HOME/.vim/colors" "$HOME/.config/fastfetch"
curl -fsSL "$RAW/.p10k.zsh" -o "$HOME/.p10k.zsh"
curl -fsSL "$RAW/.vimrc" -o "$HOME/.vimrc"
curl -fsSL "$CODEDARK" -o "$HOME/.vim/colors/codedark.vim"

if command -v fastfetch >/dev/null 2>&1; then
    case "$OS" in
        arch) _ff=.config/fastfetch/config.jsonc ;;
        *)    _ff=.config/fastfetch/server.jsonc ;;
    esac
    curl -fsSL "$RAW/$_ff" -o "$HOME/.config/fastfetch/config.jsonc" || echo "warning: fastfetch config download failed"
fi

# ---------------------------------------------------------------- root copy
DO_ROOT=no
if [ "$OS" != termux ] && [ "$(id -u)" != 0 ]; then
    if ask "Also apply to root? " y; then
        DO_ROOT=yes
        $SUDO rm -rf /root/.oh-my-zsh /root/.vim /root/.config/fastfetch
        $SUDO mkdir -p /root/.config
        $SUDO cp -r "$HOME/.oh-my-zsh" /root/
        $SUDO cp -r "$HOME/.vim" /root/
        $SUDO cp "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.vimrc" /root/
        if [ -d "$HOME/.config/fastfetch" ]; then
            $SUDO cp -r "$HOME/.config/fastfetch" /root/.config/
        fi
    fi
fi

# ---------------------------------------------------------------- shell
zsh_path=$(command -v zsh || true)
if [ -n "$zsh_path" ]; then
    if [ "$OS" = termux ]; then
        chsh -s zsh || echo "warning: chsh failed"
    else
        grep -qx "$zsh_path" /etc/shells 2>/dev/null || \
            echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null
        $SUDO usermod -s "$zsh_path" "$(id -un)" || echo "warning: usermod failed"
        if [ "$DO_ROOT" = yes ]; then
            $SUDO usermod -s "$zsh_path" root || echo "warning: usermod root failed"
        fi
    fi
fi

echo "Done. Enjoy your shell."
if [ -t 0 ] && [ -t 1 ]; then
    exec zsh -l
fi
