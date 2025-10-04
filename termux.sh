#!/bin/bash
#
pkg update
pkg install git wget which zsh vim
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -e 's|ZSH_THEME="robbyrussell"|ZSH_THEME="powerlevel10k/powerlevel10k"|g' -e 's|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|g' -i ~/.zshrc
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.p10k.zsh -O ~/.p10k.zsh
wget https://github.com/tomasiser/vim-code-dark/raw/refs/heads/master/colors/codedark.vim -P /data/data/com.termux/files/usr/share/vim/vim*/colors
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.vimrc -O ~/.vimrc
chsh -s zsh
