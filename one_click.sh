#!/bin/bash
# CentOS 7 一键初始化脚本
# 注意：CentOS 7 已于 2024-06-30 EOL；aliyun 的 Centos-7.repo 现已迁移至 vault 归档仓库。

if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

#换源
read -rp $'是否换源为ali源,y or n\n' _source_
if [ "$_source_" = y ]; then
if curl -fsSL -o /tmp/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo; then
rm -f /etc/yum.repos.d/*
mv /tmp/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
yum clean all
yum makecache
echo "换源成功 "
else
echo "下载源失败，保持原有源不变 "
fi
else
	echo "跳过换源 "
fi

#安装zsh和oh-my-zsh
read -rp $'是否安装zsh和oh-my-zsh,y or n\n' _zsh_
if [ "$_zsh_" = y ]; then
yum install -y zsh git curl
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s /usr/bin/zsh
echo "zsh配置完成 "
else
	echo "跳过安装zsh "
fi

#设置 ssh 超时时间为至少 10 分钟
grep -q "ServerAliveInterval 60" /etc/ssh/ssh_config || echo "ServerAliveInterval 60" >> /etc/ssh/ssh_config
grep -q "ServerAliveCountMax 3" /etc/ssh/ssh_config || echo "ServerAliveCountMax 3" >> /etc/ssh/ssh_config
echo "ssh配置完成"

#git 配置邮箱用户名
echo "配置git "
read -rp $'输入您的名称和邮箱,用空格隔开\n' _name_ _email_
git config --global user.name  "$_name_"
git config --global user.email  "$_email_"
echo "git 配置完成 "

#配置全局代理
read -rp $'是否配置全局代理,y or n\n' _proxy_
if [ "$_proxy_" = y ]; then
grep -q "http_proxy=http://127.0.0.1:20171" /etc/profile || cat >> /etc/profile <<'EOF'
export http_proxy=http://127.0.0.1:20171
export https_proxy=http://127.0.0.1:20171
EOF
export http_proxy=http://127.0.0.1:20171
export https_proxy=http://127.0.0.1:20171
echo "代理配置成功 "
else
	echo "跳过配置代理 "
fi

#修改locale
localectl set-locale LANG=zh_CN.UTF-8
echo "locale更改成功 "

#升级包
yum -y update
echo "更新软件包成功 "

#安装vim
yum install -y vim
curl -fsSL -o ~/.vimrc https://raw.githubusercontent.com/wray-lee/dotfiles/main/.vimrc

#安装docker
read -rp $'是否安装docker,y or n\n' _docker_
if [ "$_docker_" = y ]; then
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
#改为自己选择的docker版本
yum -y install docker-ce-18.03.1.ce
systemctl start docker
systemctl enable docker
echo "docker安装成功 "
else
	echo "跳过安装docker "
fi

#安装nodejs
read -rp $'是否安装nodejs,y or n\n' _nodejs_
if [ "$_nodejs_" = y ]; then
git clone https://github.com/cnpm/nvm.git ~/.nvm && cd ~/.nvm && git checkout `git describe --abbrev=0 --tags`
grep -q ". ~/.nvm/nvm.sh" /etc/profile || echo ". ~/.nvm/nvm.sh" >> /etc/profile
. ~/.nvm/nvm.sh
nvm install v7.4.0
echo "nodejs安装成功 "
else
	echo "跳过安装nodejs "
fi
