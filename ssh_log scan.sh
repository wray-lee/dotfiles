#!/bin/bash

echo -e "\033[32m1.检索ip \033[0m"
echo -e "\033[32m2.登录情况\033[0m"
echo -e "\033[32m3.攻击者尝试登录\033[0m"
echo -e "请输入相应数字"
read -e num
case "$num" in
    1)
        sed -ne 's/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$/&/p' auth.log;;
    2)
        sed -ne '/Accepted/p' -e '/open/p' auth.log;;
    3)
        sed -ne 's/Received disconnect from [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}.*\[preauth\]$/&/p' auth.log;;
    *)
        exit 1;;
esac