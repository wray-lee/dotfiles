#!/bin/bash
#
echo "Do you want to change the source?(y/n)"
read -e _source_
if [ $_source_ -gt y ]; then
    echo $_password_ | sudo sed -e 's|^metalink=|#metalink=|g' \
         -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
         -i.bak \
         /etc/yum.repos.d/fedora.repo \
         /etc/yum.repos.d/fedora-modular.repo \
         /etc/yum.repos.d/fedora-updates.repo \
         /etc/yum.repos.d/fedora-updates-modular.repo
fi
sudo yum update
sudo dnf install --assumeyes zsh neofetch docker nginx git ranger bat tldr
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.vimrc -O ~/.vimrc
sudo cp ~/.vimrc /root
sed -i '1i|neofetch' .
sudo sed -e '1i neofetch' -e 's|ZSH_THEME="robbyrussell"|ZSH_THEME="powerlevel10k/powerlevel10k"|g' -e 's|plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|g' -i ~/.zshrc
sudo cp ~/.zshrc /root
wget -c https://raw.githubusercontent.com/wray-lee/one_click/main/.p10k.zsh -O ~/.p10k.zsh
sudo cp ~/.p10k.zsh /root
sudo cp -r ./.oh-my-zsh /root/.oh-my-zsh
#chsh -s /usr/bin/zsh
#chsh -s /usr/bin/zsh root
