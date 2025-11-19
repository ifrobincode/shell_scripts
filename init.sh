#!/bin/bash
# 指定解释器为 bash

#
# Linux 系统初始化菜单脚本（增强版）
# 作者：Robin
# 版本：v1.1
# 功能：显示系统信息 + 提供初始化任务菜单（含预留任务项）
#

# ===========================
# 颜色定义
# ===========================
RED='\033[0;31m'     # 红色，用于错误提示
GREEN='\033[0;32m'   # 绿色，用于正常信息
YELLOW='\033[1;33m'  # 黄色，用于菜单提示
NC='\033[0m'         # 无颜色（重置）

# ===========================
# 显示系统信息函数
# ===========================
show_system_info() {
    echo -e "${YELLOW}========== 系统信息 ==========${NC}"

    # 获取Linux发行版信息（从 /etc/os-release 读取）
    if [ -f /etc/os-release ]; then
        . /etc/os-release   # 引入该文件定义的变量
        echo -e "发行版名称 : ${GREEN}${NAME}${NC}"
        echo -e "发行版版本 : ${GREEN}${VERSION}${NC}"
    else
        echo -e "发行版信息 : ${RED}未知${NC}"
    fi

    # 获取内核版本
    echo -e "内核版本   : ${GREEN}$(uname -r)${NC}"

    # 获取主机名
    echo -e "主机名     : ${GREEN}$(hostname)${NC}"
    echo
}

# ===========================
# 显示菜单函数
# ===========================
show_menu() {
    echo -e "${YELLOW}========== Linux 系统初始化菜单 ==========${NC}"
    echo "1) 关闭防火墙和SELinux"
    echo "2) 添加EPEL源"
    echo "3) 安装常用软件包"
    echo "4) 优化系统与软件包配置"
    echo "5) 执行初始化任务5（预留）"
    echo "q) 退出脚本"
    echo -e "${YELLOW}==========================================${NC}"
}

# ===========================
# 任务函数（可自行替换实际操作）
# ===========================

task1() {
    echo -e "${GREEN}执行任务1：关闭防火墙和SELinux${NC}"

    echo -e "\n${YELLOW}>>> 正在关闭firewalld...${NC}"
    # 关闭防火墙立即生效
    systemctl stop firewalld 2>/dev/null
    # 禁止开机自动启动
    systemctl disable firewalld 2>/dev/null

    # 检查是否成功
    if systemctl is-active firewalld >/dev/null 2>&1; then
        echo -e "${RED}防火墙关闭失败！${NC}"
    else
        echo -e "${GREEN}防火墙已关闭，并设置为开机不启动。${NC}"
    fi

    echo -e "\n${YELLOW}>>> 正在关闭SELinux...${NC}"

    # 立即关闭 SELinux（临时）
    setenforce 0 2>/dev/null

    # 永久修改 /etc/selinux/config
    if [ -f /etc/selinux/config ]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        echo -e "${GREEN}SELinux已修改为永久关闭（需要重启生效）。${NC}"
    else
        echo -e "${RED}/etc/selinux/config 文件不存在，无法永久关闭SELinux！${NC}"
    fi

    # 显示当前 SELinux 状态
    echo -e "当前SELinux模式：${GREEN}$(getenforce)${NC}"

    echo -e "\n${GREEN}任务1执行完成：防火墙与SELinux已关闭。${NC}"
}


task2() {
    echo -e "${GREEN}执行任务2：例如配置主机名、时区等${NC}"
    # 示例操作：
    # timedatectl set-timezone Asia/Shanghai
}

task3() {
    echo -e "${GREEN}执行任务3：例如创建常用用户和目录${NC}"
    # 示例操作：
    # useradd deploy && mkdir -p /data
}

task4() {
    echo -e "${GREEN}执行任务4：例如优化系统参数sysctl${NC}"
    # 示例操作：
    # sysctl -w net.ipv4.ip_forward=1
}

task5() {
    echo -e "${GREEN}执行任务5：例如设置防火墙规则${NC}"
    # 示例操作：
    # firewall-cmd --add-service=ssh --permanent && firewall-cmd --reload
}

# ===========================
# 主程序执行部分
# ===========================

# 先显示系统信息（只显示一次）
show_system_info

# 进入主循环，展示菜单并等待用户输入
while true; do
    show_menu
    read -p "请输入选项编号（1-5 或 q 退出）: " choice
    case $choice in
        1) task1 ;;
        2) task2 ;;
        3) task3 ;;
        4) task4 ;;
        5) task5 ;;
        q|Q)
            echo -e "${YELLOW}已退出脚本。${NC}"
            break
            ;;
        *)
            echo -e "${RED}无效选项，请重新输入。${NC}"
            ;;
    esac
    echo
done
