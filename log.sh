#!/bin/bash

confirm_cleanup() {
    local log_file=$1
    if [ ! -s "$log_file" ]; then
        echo "确认：${log_file} 已被清理。"
    else
        echo "警告：${log_file} 仍然包含数据。"
    fi
}

cleanup_log_file() {
    local log_file=$1
    local log_name=$2
    echo "正在清理 ${log_name}..."
    cat /dev/null > "${log_file}"
    if [ $? -eq 0 ]; then
        echo "${log_name} 清理完成。"
    else
        echo "${log_name} 清理失败。"
    fi
    confirm_cleanup "${log_file}"
}

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
        "登录成功日志"
        "登录失败日志"
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
        echo "$((i+1)). 清理 ${names[i]}"
    done
    read -p "请输入要清理的日志文件编号（或输入 'q' 退出）: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#options[@]}" ]; then
        local index=$((input-1))
        cleanup_log_file "${options[$index]}" "${names[$index]}"
    elif [ "$input" == 'q' ]; then
        echo "退出清理操作。"
    else
        echo "无效输入，请再试一次。"
    fi
}

cleanup_all_logs() {
    echo "正在清理所有日志文件，包括没有后缀的、归档的和压缩的..."
    find /var/log -type f \( -name "*.log" -o -name "syslog" -o -name "btmp" -o -name "*.log.*" -o -name "*.gz" \) -exec rm -f {} \;
    echo "所有日志文件的清理尝试完成。"
}

cleanup_junk() {
    echo "清理系统垃圾和临时文件..."
    rm -rf /tmp/* /var/tmp/*
    echo "系统垃圾和临时文件清理完成。"
}

cleanup_user_history() {
    echo "正在清理用户命令历史..."
    history -c && history -w
    echo "用户命令历史已清理。"
}

cleanup_package_cache() {
    echo "清理包管理器缓存..."
    if type apt-get >/dev/null 2>&1; then
        apt-get clean
        apt-get autoclean
    elif type yum >/dev/null 2>&1; then
        yum clean all
    elif type zypper >/dev/null 2>&1; then
        zypper clean
    elif type pacman >/dev/null 2>&1; then
        pacman -Sc
    else
        echo "未发现已知的包管理器。"
    fi
    echo "包管理器缓存已清理。"
}

display_specific_log() {
    echo "请选择要显示的日志文件："
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
        "登录成功日志"
        "登录失败日志"
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
        echo "$((i+1)). 显示 ${names[i]}"
    done
    read -p "请输入要显示的日志文件编号（或输入 'q' 退出）: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#options[@]}" ]; then
        clear
        local index=$((input-1))
        tail -f "${options[$index]}"
    elif [ "$input" == 'q' ]; then
        echo "退出显示操作。"
    else
        echo "无效输入，请再试一次。"
    fi
}

detect_os() {
    if type apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif type yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    elif type zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    elif type pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    else
        echo "不支持的包管理器。"
        return 1
    fi
    echo "已检测到包管理器: $PKG_MANAGER"
}

main_menu() {
    while true; do
        echo "请选择要执行的清理任务："
        echo "1) 清理特定日志文件"
        echo "2) 清理所有日志文件"
        echo "3) 清理系统垃圾和临时文件"
        echo "4) 清理用户命令历史"
        echo "5) 清理包管理器缓存"
        echo "6) 显示特定日志文件"
        echo "7) 删除这个脚本"
        echo "8) 退出程序"
        read -p "请输入选项 (1-8): " choice
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
                cleanup_user_history
                ;;
            5)
                cleanup_package_cache
                ;;
            6)
                display_specific_log
                ;;
            7)
                rm -- "$0"; exit
                ;;
            8)
                echo "退出程序。"; break
                ;;
            *)
                echo "无效选项，请重新输入。"
                ;;
        esac
    done
}

# 初始化脚本
detect_os
# 显示主菜单，直到用户选择退出
main_menu
