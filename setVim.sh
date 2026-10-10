#!/bin/sh
set -eu
mkdir -p ~/.vim/colors
curl -fsSL https://raw.githubusercontent.com/tomasiser/vim-code-dark/master/colors/codedark.vim -o ~/.vim/colors/codedark.vim
curl -fsSL https://raw.githubusercontent.com/wray-lee/dotfiles/main/.vimrc -o ~/.vimrc
