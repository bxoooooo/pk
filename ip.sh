#!/bin/bash

# 日志文件
LOG="/var/log/country_block.log"

# 确认当前用户是否为root
root_need() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "请以root用户运行此脚本。"
        exit 1
    fi
}

# 检查Linux发行版本并设置相应变量
check_release() {
    if [ -f /etc/redhat-release ]; then
        release="centos"
    elif grep -iq debian /etc/os-release; then
        release="debian"
    elif grep -iq ubuntu /etc/os-release; then
        release="ubuntu"
    else
        echo "您的系统不在脚本自动化支持的范围内，请手动设置iptables规则，或者更换系统至CentOS/Debian/Ubuntu。"
        exit 1
    fi
}

# 如果没有安装ipset，则尝试进行安装
check_ipset() {
    if ! command -v ipset &> /dev/null; then
        echo "ipset未安装，正在尝试为您安装ipset..."
        if [ "$release" == "centos" ]; then
            yum -y install ipset || { echo "尝试安装ipset失败，请检查您的网络连接后重试。"; exit 1; }
        elif [ "$release" == "debian" ] || [ "$release" == "ubuntu" ]; then
            apt -y install ipset || { echo "尝试安装ipset失败，请检查您的网络连接后重试。"; exit 1; }
        fi
    fi
}

# 如果没有安装iptables，则尝试进行安装
check_iptables() {
    if ! command -v iptables &> /dev/null; then
        echo "iptables未安装，正在尝试为您安装iptables..."
        if [ "$release" == "centos" ]; then
            yum -y install iptables-services || { echo "尝试安装iptables失败，请检查您的网络连接后重试。"; exit 1; }
        elif [ "$release" == "debian" ] || [ "$release" == "ubuntu" ]; then
            apt -y install iptables || { echo "尝试安装iptables失败，请检查您的网络连接后重试。"; exit 1; }
        fi
    fi
}
# 封禁某个国家的所有IP
block_ipset() {
    echo "请输入需要封禁IP的国家代码(如cn,us)，注意小写:"
    read country
    ipset -N $country hash:net
    for ip in $(wget -qO- http://www.ipdeny.com/ipblocks/data/countries/$country.zone)
    do
        ipset -A $country $ip
    done
    iptables -I INPUT -p tcp -m set --match-set $country src -j DROP
    echo "已封禁 $country 国家的所有IP。"
}

# 解封某个国家的所有IP
unblock_ipset() {
    echo "请输入需要解封IP的国家代码(如cn,us)，注意小写:"
    read country
    iptables -D INPUT -p tcp -m set --match-set $country src -j DROP
    ipset destroy $country
    echo "已解封 $country 国家的所有IP。"
}

# 添加单个IP到黑名单
block_single_ip() {
    echo "请输入需要封禁的IP地址:"
    read ip
    iptables -A INPUT -s $ip -j DROP
    echo "已将IP地址 $ip 封禁。"
}

# 从黑名单中移除单个IP
unblock_single_ip() {
    echo "请输入需要解封的IP地址:"
    read ip
    iptables -D INPUT -s $ip -j DROP
    echo "已将IP地址 $ip 解封。"
}

# 查看已封禁的IP列表
block_list() {
    echo "封禁的IP列表如下:"
    iptables -nL INPUT | grep DROP
}

# 更新某个国家的IP名单
update_ipset() {
    echo "请输入需要更新IP名单的国家代码(如cn,us)，注意小写:"
    read country
    ipset destroy $country
    ipset -N $country hash:net
    for ip in $(wget -qO- http://www.ipdeny.com/ipblocks/data/countries/$country.zone)
    do
        ipset -A $country $ip
    done
    echo "已更新 $country 国家的IP名单。"
}
# 封禁所有IP，可选是否放行Cloudflare和当前SSH会话的IP
block_all() {
    echo "即将封禁所有IP地址"
    read -p "是否放行Cloudflare的CDN IP? (y/n)：" cf_response
    read -p "是否放行当前SSH会话的IP? (y/n)：" ssh_response

    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    if [ "$cf_response" = "y" ]; then
        for ip in $(curl https://www.cloudflare.com/ips-v4); do
            iptables -I INPUT -s $ip -j ACCEPT
        done
        for ip in $(curl https://www.cloudflare.com/ips-v6); do
            iptables -I INPUT -s $ip -j ACCEPT
        done
    fi

    if [ "$ssh_response" = "y" ]; then
        myip=$(echo $SSH_CLIENT | awk '{ print $1}')
        iptables -I INPUT -s $myip -j ACCEPT
    fi
    echo "所有IP地址已被封禁"
}

# 主函数：显示菜单并根据用户选择执行相应的功能
main() {
    clear
    echo "请选择以下操作："
    echo "1) 封禁特定国家的所有IP"
    echo "2) 解封特定国家的所有IP"
    echo "3) 封禁单个IP"
    echo "4) 解封单个IP"
    echo "5) 显示已封禁的IP列表"
    echo "6) 更新特定国家的IP名单"
    echo "7) 封禁所有IP（特殊操作）"
    echo "8) 退出"
    read -p "输入对应数字：" action

    case "$action" in
        1)
            block_ipset
            ;;
        2)
            unblock_ipset
            ;;
        3)
            block_single_ip
            ;;
        4)
            unblock_single_ip
            ;;
        5)
            block_list
            ;;
        6)
            update_ipset
            ;;
        7)
            block_all
            ;;
        8)
            exit 0
            ;;
        *)
            echo "无效输入..."
            ;;
    esac
}

# 脚本运行的顺序

root_need
check_release
check_ipset
check_iptables
main
