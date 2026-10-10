#!/bin/bash

# 日志来源: 参数1 > /var/log/auth.log > /var/log/secure > journalctl
if [ -n "${1:-}" ]; then
    LOG_SRC="$1"
elif [ -r /var/log/auth.log ]; then
    LOG_SRC="/var/log/auth.log"
elif [ -r /var/log/secure ]; then
    LOG_SRC="/var/log/secure"
else
    LOG_SRC=""
fi

logs() {
    if [ -n "$LOG_SRC" ]; then
        cat "$LOG_SRC"
    else
        journalctl -u sshd -u ssh --no-pager
    fi
}

echo -e "\033[32m1.检索ip \033[0m"
echo -e "\033[32m2.登录情况\033[0m"
echo -e "\033[32m3.攻击者尝试登录\033[0m"
echo -e "请输入相应数字"
read -r num
case "$num" in
    1)
        logs | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn;;
    2)
        logs | grep -E 'Accepted|session opened';;
    3)
        logs | grep -E 'Failed password|Invalid user|preauth';;
    *)
        exit 1;;
esac
