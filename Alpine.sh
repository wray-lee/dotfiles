#!/bin/bash
#
sudo apk update
sudo apk add zsh git neofetch nginx git bat procps iproute2 coreutils
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
echo "net.core.default_qdisc=cake" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
wget https://github.com/tomasiser/vim-code-dark/raw/refs/heads/master/colors/codedark.vim -P /usr/share/vim/vim*/colors
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.vimrc -O ~/.vimrc
sudo cp ~/.vimrc /root
sudo sed -e 's|ZSH_THEME="robbyrussell"|ZSH_THEME="powerlevel10k/powerlevel10k"|g' -e 's|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|g' -i ~/.zshrc
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.p10k.zsh -O ~/.p10k.zsh
sudo cp ~/.p10k.zsh /root
sudo cp -r ./.oh-my-zsh /root/.oh-my-zsh
mkdir -p ~/.config/fastfetch
#wget -c https://raw.githubusercontent.com/wray-lee/one_click/refs/heads/main/.config/fastfetch/config.jsonc -P ~/.config/fastfetch/
wget -c https://raw.githubusercontent.com/wray-lee/one_click/refs/heads/main/.config/fastfetch/server.jsonc -O ~/.config/fastfetch/config.jsonc
sudo cp ~/.zshrc /root
sed -i '1i neofetch' .zshrc
#chsh -s /usr/bin/zsh
#chsh -s /usr/bin/zsh root
