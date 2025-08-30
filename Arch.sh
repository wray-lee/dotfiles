#!/bin/bash
#
sudo pacman -S --noconfirm zsh fastfetch docker nginx git ranger bat tldr lsd duf zoxide fd btop nmap
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
wget https://github.com/tomasiser/vim-code-dark/raw/refs/heads/master/colors/codedark.vim -P /usr/share/vim/vim*/colors
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.vimrc -O ~/.vimrc
sudo cp ~/.vimrc /root
sudo sudo sed -e '1i neofetch' -e 's|ZSH_THEME="robbyrussell"|ZSH_THEME="powerlevel10k/powerlevel10k"|g' -e 's|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|g' -i ~/.zshrc
sudo cp ~/.zshrc /root
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.p10k.zsh -O ~/.p10k.zsh
sudo cp ~/.p10k.zsh /root
mkdir -p ~/.config/fastfetch
wget -c https://raw.githubusercontent.com/wray-lee/dotfiles/refs/heads/main/.config/fastfetch/config.jsonc -O ~/.config/fastfetch
sudo cp -r ~/.config/fastfetch /root/.config
#chsh -s /usr/bin/zsh
#chsh -s /usr/bin/zsh root
