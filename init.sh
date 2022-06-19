#!/bin/bash

Green_font="\033[32m"
Red_font="\033[31m"
Font_suffix="\033[0m"
Info="[${Green_font}Info${Font_suffix}] "
Error="[${Red_font}Error${Font_suffix}] "

if [ $UID -ne 0 ]; then
  echo -e "\n$Error 权限不足，请使用 Root 用户\n"
  exit
fi

echo -e "$Info 本脚本仅适用于debian bullseye"
read -p "按任意键继续 Ctrl+C退出"

echo -e "$Info 正在禁用ipv6"
sed -i 's/#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf

echo "$Info 正在替换源"
cat >/etc/apt/sources.list <<EOF
deb http://mirrors.cloud.tencent.com/debian bullseye main contrib
deb http://mirrors.cloud.tencent.com/debian bullseye-updates main contrib
deb http://mirrors.cloud.tencent.com/debian-security bullseye-security main contrib
EOF

echo "$Info 正在更新源"
apt-get update

echo "$Info 正在修改日志最大大小"
echo "HISTSIZE=100000" >> /etc/profile

cat >>/etc/bashrc <<EOF
export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
PS1='\[\e[37m\][\[\e[32m\]\u\[\e[37m\]@\h \[\e[36m\]\W\[\e[0m\]]\$ '
EOF

echo "$Info 修改完成，3秒后重启系统"
sleep 3
reboot
