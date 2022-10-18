#!/bin/bash


#换源
read -p "是否换源为ali源,y or n `echo $'\n'`" _source_
if [$_source_ == y];	then
rm /etc/yum.repos.d/*
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum makecache
yum install -y
echo "换源成功 "
else 
	"跳过换源 "
fi

#安装zsh和oh-my-zsh
read -p "是否安装zsh和oh-my-zsh,y or n `echo $'\n'`"	_zsh_
if [$_zsh_ == y];	then
yum install -y zsh git
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | sh
chsh -s /usr/bin/zsh
echo "zsh配置完成 "
else 
	echo "跳过安装zsh "
fi

#设置 ssh 超时时间为至少 10 分钟
echo "ServerAliveInterval 60" >> /etc/ssh/ssh_config
echo "ServerAliveCountMax 3 " >> /etc/ssh/ssh_config
source /etc/ssh/ssh_config
echo "ssh配置完成"

#git 配置邮箱用户名
echo "配置git "
read -p "输入您的名称和邮箱,用空格隔开 `echo $'\n'`" _name_	_email_
git config --global user.name  "$_name_"
git config --global user.email  "$email"
echo "git 配置完成 "

#配置全局代理
echo "export http://127.0.0.1:20171" >> /etc/profile
echo "export https_proxy=http://127.0.0.1:20171" >> /etc/profile
source /etc/profile
export http_proxy
export https_proxy
echo "代理配置成功 "

#修改locale
localectl set-locale LANG=zh_CN.UTF-8
echo "locale更改成功 "

#升级包
yum -y update
echo "更新软件包成功 "

#安装vim
yum install vim 
mv ./.vimrc ~/.vimrc

#安装docker
read -p "是否安装docker,y or n `echo $'\n'`"	_docker_
if [$_docker_== y];	then
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
read -p "是否安装nodejs,y or n `echo $'\n'`"	_nodejs_
if [$_nodejs_ == y];	then
git clone https://github.com/cnpm/nvm.git ~/.nvm && cd ~/.nvm && git checkout `git describe --abbrev=0 --tags`
echo ". ~/.nvm/nvm.sh" >> /etc/profile
source /etc/profile
nvm install v7.4.0
echo "nodejs安装成功 "
else
	echo "跳过安装nodejs "
fi
