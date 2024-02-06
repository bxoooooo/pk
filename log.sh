#!/bin/bash

# 高级可视化清理脚本

# 函数: 清理日志文件
cleanup_log_file() {
    log_file=$1
    log_name=$2
    echo "清理 ${log_name}..."
    cat /dev/null > "${log_file}"
    echo "${log_name} 已清理。"
}

# 函数: 清理特定的日志文件
cleanup_specific_log() {
    echo "请选择要清理的日志文件："
    local options=(
        "/var/log/syslog"
        "/var/log/cron"
        "/var/log/wtmp"
        "/var/log/btmp"
        "/var/log/dmesg"
        "/var/log/secure"
        "/var/log/messages"
        "/var/log/lastlog"
        "/var/log/maillog"
        "/var/log/yum.log"
        "/var/log/auth.log"
        "/var/log/boot.log"
        "/var/log/daemon.log"
        "/var/log/dpkg.log"
        "/var/log/kern.log"
        "/var/log/user.log"
    )
    local names=(
        "系统日志"
        "定时任务日志"
        "登陆成功日志"
        "登陆失败日志"
        "系统启动消息日志"
        "安全相关日志"
        "系统消息日志"
        "用户最后登录日志"
        "邮件日志"
        "YUM 包管理器日志"
        "认证日志"
        "启动日志"
        "守护进程日志"
        "DPKG包管理器日志"
        "内核日志"
        "用户级日志"
    )
        for i in "${!options[@]}"; do
        echo "$((i+1))) 清理 ${names[i]}"
    done

    read -p "请输入要清理的日志文件编号（或输入 'q' 退出）: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#options[@]}" ]; then
        index=$((input-1))
        cleanup_log_file "${options[$index]}" "${names[$index]}"
    elif [ "$input" == 'q' ]; then
        echo "退出清理操作。"
    else
        echo "无效输入，请再试一次。"
    fi
}

# 函数: 清理所有日志文件
cleanup_all_logs() {
    echo "正在清理所有日志文件..."
    find /var/log -type f -name "*.log" -exec cat /dev/null > {} \;
    echo "所有日志文件已清理。"
}
# 函数: 清理系统垃圾和临时文件
cleanup_junk() {
    echo "清理系统垃圾和临时文件..."
    # 添加具体的清理临时文件和系统垃圾的命令
    rm -rf /tmp/* /var/tmp/*
    echo "系统垃圾和临时文件清理完成。"
}

# 函数: 清理包管理器缓存
cleanup_package_cache() {
    echo "清理包管理器缓存..."
    # 添加对不同包管理器的支持 (apt, yum等)
    if [[ $PKG_MANAGER == "apt" ]]; then
        apt-get clean
        apt-get autoclean
    elif [[ $PKG_MANAGER == "yum" ]]; then
        yum clean all
    fi
    echo "包管理器缓存已清理。"
}
# 函数: 检测操作系统类型并设置包管理器变量
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "debian" ] || [ "$ID_LIKE" = "debian" ]; then
            PKG_MANAGER="apt"
        elif [ "$ID" = "centos" ] || [ "$ID" = "fedora" ] || [ "$ID" = "rhel" ]; then
            PKG_MANAGER="yum"
        else
            echo "不支持的操作系统。"
            exit 1
        fi
    else
        echo "无法检测到操作系统类型。"
        exit 1
    fi
}

# 主程序逻辑
detect_os

echo "请选择要执行的清理任务："
echo "1) 清理特定日志文件"
echo "2) 清理所有日志文件"
echo "3) 清理系统垃圾和临时文件"
echo "4) 清理包管理器缓存"
echo "5) 退出"


read -p "请输入选择 (1-5): " choice

case "$choice" in
    1)
        cleanup_specific_log
        ;;
    2)
        cleanup_all_logs
        ;;
    3)
        cleanup_junk
        ;;
    4)
        cleanup_package_cache
        ;;
    5)
        echo "退出程序。"
        ;;
    *)
        echo "无效选项。"
        ;;
esac

echo "操作完成。"
