#!/bin/bash

# Log 文件
LOG="/var/log/country_block.log"

block_ipset() {
    echo -e "请输入需要封禁的国家代码，如cn(中国)，注意字母为小写！"
    read -e -p "请输入国家代码:" GEOIP
    wget -P /tmp http://www.ipdeny.com/ipblocks/data/countries/$GEOIP.zone 2>> $LOG

    # 检查下载是否成功，如果失败则重试一次
    if [ -f "/tmp/"$GEOIP".zone" ]; then
        echo "$(date "+%Y/%m/%d %H:%M:%S") - IPs data downloaded successfully！" >> $LOG
    else
        echo "$(date "+%Y/%m/%d %H:%M:%S") - IPs data download failed, retrying..." >> $LOG
        rm -f /tmp/$GEOIP.zone
        wget -P /tmp http://www.ipdeny.com/ipblocks/data/countries/$GEOIP.zone 2>> $LOG
        if [ ! -f "/tmp/"$GEOIP".zone" ]; then
            echo "$(date "+%Y/%m/%d %H:%M:%S") - Retry failed, script is aborting！" >> $LOG
            exit 112
        fi
    fi

    ipset -N $GEOIP hash:net 2>> $LOG
    for i in $(cat /tmp/$GEOIP.zone ); do ipset -A $GEOIP $i; done
    rm -f /tmp/$GEOIP.zone

    iptables -I INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
    iptables -I INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
    echo "$(date "+%Y/%m/%d %H:%M:%S") - All IPs from country $GEOIP were successfully blocked!" >> $LOG
}

unblock_ipset() {
    echo -e "Please input the country code to unblock, for example, cn for China, letters are lowercase！"
    read -p "请输入国家代码:" GEOIP
    lookuplist=`ipset list | grep "Name:" | grep "$GEOIP"`

    if [ -n "$lookuplist" ]; then
        iptables -D INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
        iptables -D INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
        ipset destroy $GEOIP
        echo "$(date "+%Y/%m/%d %H:%M:%S") - The IP from the specified country ($GEOIP) was successfully unblocked, and the corresponding rules        were deleted！" >> $LOG
    else
        echo "$(date "+%Y/%m/%d %H:%M:%S") - Failed to unblock! The country ($GEOIP) you want to unblock is not on the blocking list！" >> $LOG
        exit 112
    fi
}

block_list() {
    blocked=`iptables -L | grep match-set`
    if [ -n "$blocked" ]; then
        echo "$(date "+%Y/%m/%d %H:%M:%S") - The current blocking list is as follows："
        iptables -L | grep match-set
    else
        echo "$(date "+%Y/%m/%d %H:%M:%S") - The current blocking list is empty！"
    fi
}

update_ipset() {
    echo -e "请输入需要更新的国家代码，如cn(中国)，注意字母为小写！"
    read -p "请输入国家代码:" GEOIP
    wget -P /tmp http://www.ipdeny.com/ipblocks/data/countries/$GEOIP.zone 2>> $LOG

    if [ -f "/tmp/"$GEOIP".zone" ]; then
        echo "$(date "+%Y/%m/%d %H:%M:%S") - IPs data downloaded successfully！" >> $LOG
    else
        echo "$(date "+%Y/%m/%d %H:%M:%S") - IPs data download failed, retrying..." >> $LOG
        rm -f /tmp/$GEOIP.zone
        wget -P /tmp http://www.ipdeny.com/ipblocks/data/countries/$GEOIP.zone 2>> $LOG
        if [ ! -f "/tmp/"$GEOIP".zone" ]; then
            echo "$(date "+%Y/%m/%d %H:%M:%S") - Retry failed, script is aborting！" >> $LOG
            exit 1
        fi
    fi
    echo "$(date "+%Y/%m/%d %H:%M:%S") - The IP list of the specified country ($GEOIP) has been updated successfully！" >> $LOG
}

block_single_ip() {
    echo -e "请输入需要封禁的IP地址："
    read -e -p "请输入IP地址：" IP
    iptables -A INPUT -s $IP -j DROP
    echo "$(date "+%Y/%m/%d %H:%M:%S") - IP $IP has been blocked！" >> $LOG
}

unblock_single_ip() {
    echo -e "请输入需要解封的IP地址："
    read -e -p "请输入IP地址：" IP
    iptables -D INPUT -s $IP -j DROP
    echo "$(date "+%Y/%m/%d %H:%M:%S") - IP $IP has been unblocked！" >> $LOG
}

check_release() {
    if [ -f /etc/redhat-release ];then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
}

check_ipset() {
    if [ -f /sbin/ipset ]; then
        echo "$(date "+%Y/%m/%d %H:%M:%S") - ipset detected and exists, skipping the installation step！" >> $LOG
    elif [ "${release}" == "centos" ]; then
        yum -y install ipset >> $LOG
    else
        apt-get -y install ipset >> $LOG
    fi
}

check_iptables() {
    which iptables > /dev/null || {
        echo "iptables not installed! Installing now..."
        if [ "${release}" == "centos" ]; then
            yum install iptables-services -y >> $LOG
        else
            apt-get install iptables -y >> $LOG
        fi
    }
}

# 封禁所有IP，并提供选项以放行Cloudflare和当前SSH会话的IP
block_all() {
    echo "封禁所有的IP地址。"
    read -p "是否放行Cloudflare的CDN IP? (y/n): " cf_response
    read -p "是否放行当前SSH会话的IP? (y/n): " ssh_response

    myip=$(echo $SSH_CLIENT | awk '{ print $1}')
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    if [ "$cf_response" == "y" ]; then
        # 获取Cloudflare的IP并放行
        for ip in $(curl https://www.cloudflare.com/ips-v4); do
            iptables -I INPUT -s $ip -j ACCEPT
        done
        for ip in $(curl https://www.cloudflare.com/ips-v6); do
            iptables -I INPUT -s $ip -j ACCEPT
        done
    fi

    if [ "$ssh_response" == "y" ]; then
        if [ -z "$myip" ]; then
            echo "无法获取当前SSH会话的IP地址。"
        else
            iptables -I INPUT -p tcp -s $myip --dport 22 -j ACCEPT
        fi
    fi

    echo "已封禁所有IP，根据选择放行特定IP。"
}

main() {
    clear
    echo -e "———————————————————————————————————————"
    echo -e "一键屏蔽指定国家所有的IP访问脚本"
    echo -e "1、封禁指定国家的IP"
    echo -e "2、解封指定国家的IP"
    echo -e "3、查看封禁列表"
    echo -e "4、更新指定国家的IP列表"
    echo -e "5、封禁指定的IP"
    echo -e "6、解封指定的IP"
    echo -e "7、封禁所有IP"
    echo -e "8、退出脚本"
    echo -e "———————————————————————————————————————"
    read -p "请输入数字 [1-8]：" num
    case "$num" in
        1)
            block_ipset
            ;;
        2)
            unblock_ipset
            ;;
        3)
            block_list
            ;;
        4)
            update_ipset
            ;;
        5)
            block_single_ip
            ;;
        6)
            unblock_single_ip
            ;;
        7)
            block_all
            ;;
        8)
            exit 0
            ;;
        *)
            echo -e "请选择正确的数字 [1-8]："
            sleep 5s
            main
            ;;
    esac
}

root_need()
{
    if [[ "$(id -u)" -ne 0 ]]
    then
        echo "Please run the script as root!"
        exit 1
    fi
}

root_need
check_release
check_ipset
check_iptables
main
