#!/bin/bash
#
read -p "Password" _password_
echo $_password_ | sudo pacman -S --noconfirm zsh neofetch docker nginx
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.vimrc -O ~/.vimrc
sudo cp ~/.vimrc /root
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.vimrc -O ~/.zshrc
sudo cp ~/.zshrc /root
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.p10k.zsh -O ~/.p10k.zsh
sudo cp ~/.p10k.zsh /root