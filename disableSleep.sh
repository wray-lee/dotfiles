#!/bin/bash

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/nosleep.conf > /dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
EOF

echo "配置完成，请运行 'systemctl restart systemd-logind' 或重启系统使其生效"
echo "（注意：重启 systemd-logind 会终止当前图形会话）"
