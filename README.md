# dotfiles

Personal dotfiles and bootstrap scripts for various Linux distros.

## Quick Bootstrap

**Setup:** `sh -c "$(curl -fsSL https://raw.githubusercontent.com/wray-lee/dotfiles/main/setup.sh)"`

(or `wget https://raw.githubusercontent.com/wray-lee/dotfiles/main/setup.sh && sh setup.sh`)

Supported: Arch / Debian / Ubuntu / Fedora / Alpine / Termux.

**Arch install (from the Arch ISO):** `curl -fsSLO https://raw.githubusercontent.com/wray-lee/dotfiles/main/arch-install.sh && bash arch-install.sh`
Add a disk to the LVM root: `bash arch-install.sh extend /dev/sdX`

**Cert:** `bash <(curl -fsSL https://raw.githubusercontent.com/wray-lee/dotfiles/main/gencrt.sh)`

**vim:** `wget https://raw.githubusercontent.com/wray-lee/dotfiles/main/setVim.sh && sh setVim.sh`
