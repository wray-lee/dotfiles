#!/bin/bash
#
echo "Do you want to change the source?(y/n)"
read -e _source_
if [ $_source_ = "y" ]; then
    sudo sed -i.bak 's|deb.debian.org|mirrors.pku.edu.cn|g' /etc/apt/sources.list
    sudo sed -i.bak 's|security.debian.org|mirrors.pku.edu.cn|g' /etc/apt/sources.list
fi
sudo apt update
sudo apt install -y zsh neofetch nginx git ranger bat tldr apt-transport-https ca-certificates curl gnupg2 software-properties-common fd-find zoxide duf lsd btop nmap
mkdir -p /etc/apt/keyrings
curl -fsSL https://mirrors.pku.edu.cn/docker-ce/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.pku.edu.cn/docker-ce/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce
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
