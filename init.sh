#!/bin/bash

# ----------------------------- Linux 系统初始化脚本 -----------------------------
# 脚本名称: init.sh
# 版本信息: version: 2026.03.29.02
# 更新日期: 2026-03-29
# 更新内容:
#   1. 在 Docker 安装成功后，新增显示 docker compose 版本信息
#   2. 更新主菜单结构：
#      - 原 "3) 安装常用软件包" 改为 "3) 安装常用软件包（包管理工具安装）"
#      - 新增 "4) 安装常用软件包（非包管理工具安装）"
#      - 原 "4) 系统及软件优化" 调整为 "5)"
#      - 原 "5) 安装容器" 调整为 "6)"
#      - 新增 "7) 预留功能（未来扩展）"
#      - 新增 "r) 重启系统"
#   3. 实现新增的两个功能函数（非包管理工具安装 + 系统重启）
# 测试系统: Rocky 9.6 / Ubuntu 24.04
# 作者: Robin
# 注意: 本脚本必须以 root 权限运行，生产环境使用前请仔细审查并做好备份！

# ----------------------------- 颜色与样式定义 -----------------------------

# --- 前景色（文本颜色）---
# 基础色（0-7）
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# 高亮色（亮色，90-97）
L_BLACK='\033[0;90m'   # 灰色
L_RED='\033[0;91m'
L_GREEN='\033[0;92m'
L_YELLOW='\033[0;93m'
L_BLUE='\033[0;94m'
L_MAGENTA='\033[0;95m'
L_CYAN='\033[0;96m'
L_WHITE='\033[0;97m'

# --- 背景色 ---
BG_BLACK='\033[0;40m'
BG_RED='\033[0;41m'
BG_GREEN='\033[0;42m'
BG_YELLOW='\033[0;43m'
BG_BLUE='\033[0;44m'
BG_MAGENTA='\033[0;45m'
BG_CYAN='\033[0;46m'
BG_WHITE='\033[0;47m'

# --- 样式（可叠加）---
BOLD='\033[1m'         # 加粗
DIM='\033[2m'          # 暗淡
UNDERLINE='\033[4m'    # 下划线
BLINK='\033[5m'        # 闪烁（部分终端不支持）
REVERSE='\033[7m'      # 反显（前景/背景互换）

# --- 重置 ---
NC='\033[0m'           # No Color / Reset all attributes

# ------------------------------ 全局变量 --------------------------------------
OS_FAMILY=""            # 如：ubuntu, debian, rocky, centos, rhel
OS_VERSION=""           # 如：22.04, 9.6
PRETTY_NAME=""          # 如：Ubuntu 22.04.4 LTS

# ------------------------------ 软件包列表 ------------------------------------
# RHEL 系（Rocky/CentOS/RHEL）
RHEL_PACKAGES=(
    tree vim bash-completion wget curl lrzsz tcpdump git lsof htop
    bind-utils iputils open-vm-tools-desktop fzf zoxide
)

# Debian 系（Ubuntu/Debian）
DEBIAN_PACKAGES=(
    tree vim bash-completion wget curl lrzsz tcpdump git lsof htop psmisc
    dnsutils iputils-ping iputils-tracepath iputils-arping iputils-clockdiff
    open-vm-tools-desktop fzf zoxide
)

# ------------------------------ 权限检查 --------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：此脚本必须以 root 权限运行！${NC}" >&2
    exit 1
fi

# ------------------------------ 系统检测 --------------------------------------
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_FAMILY="${ID,,}"          # 转小写
        OS_VERSION="$VERSION_ID"
        PRETTY_NAME="$PRETTY_NAME"
    else
        echo -e "${RED}错误：无法识别操作系统（/etc/os-release 不存在）。${NC}" >&2
        exit 1
    fi
}

# ------------------------------ 获取当前用户目录 -------------------------------
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
if [[ "$TARGET_USER" == "root" ]]; then
    # 如果确实是直接以 root 登录运行（非 sudo），则 TARGET_USER 就是 root
    TARGET_USER="root"
fi

# 获取该用户的家目录（更可靠的方式）
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
    echo -e "${RED}错误：无法确定目标用户 $TARGET_USER 的家目录。${NC}" >&2
    exit 1
fi

# ------------------------------ 显示系统信息 ----------------------------------
show_system_info() {
    local ip_mask
    ip_mask=$(ip -4 addr show scope global | awk '/inet / {print $2; exit}' 2>/dev/null)

    echo -e "${YELLOW}===================== 系统信息 =====================${NC}"
    echo -e "发行版信息 : ${CYAN}${PRETTY_NAME}${NC}"
    echo -e "内核版本   : ${CYAN}$(uname -r)${NC}"
    echo -e "主机名     : ${CYAN}$(hostname)${NC}"
    echo -e "IP 地址    : ${CYAN}${ip_mask:-未获取到IP}${NC}"
    echo
}

# ------------------------------ 功能函数骨架 ----------------------------------

# -------------------------- 关闭防火墙与安全机制 -----------------------------
action_disable_security() {
    case "$OS_FAMILY" in
        rocky|centos|rhel)
            echo -e "${BLUE}>>> 正在关闭 firewalld 与 SELinux...${NC}"

            # 停止并禁用 firewalld
            if systemctl is-active --quiet firewalld; then
                systemctl stop firewalld
                systemctl disable firewalld --now 2>/dev/null
                echo -e "${GREEN}✓ firewalld 已停止并禁用。${NC}"
            else
                echo -e "${GREEN}✓ firewalld 未运行或已禁用。${NC}"
            fi

            # 临时关闭 SELinux
            if command -v getenforce >/dev/null && [[ $(getenforce) == "Enforcing" ]]; then
                setenforce 0
                echo -e "${GREEN}✓ SELinux 已临时设为 Permissive。${NC}"
            fi

            # 永久禁用 SELinux（修改配置文件）
            if [[ -f /etc/selinux/config ]]; then
                sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
                sed -i 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
                echo -e "${GREEN}✓ SELinux 已永久设为 disabled（重启后生效）。${NC}"
            else
                echo -e "${YELLOW}⚠ /etc/selinux/config 不存在，跳过永久配置。${NC}"
            fi

            echo -e "${GREEN}>>> firewalld 与 SELinux 处理完成。${NC}"
            ;;

        ubuntu|debian)
            echo -e "${BLUE}>>> 正在关闭 UFW 与 AppArmor...${NC}"

            # 关闭 UFW
            if command -v ufw >/dev/null; then
                if ufw status | grep -q "Status: active"; then
                    ufw disable --force 2>/dev/null
                    echo -e "${GREEN}✓ UFW 防火墙已禁用。${NC}"
                else
                    echo -e "${GREEN}✓ UFW 未启用。${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ ufw 未安装，跳过。${NC}"
            fi

            # 停止并禁用 AppArmor
            if systemctl is-active --quiet apparmor; then
                systemctl stop apparmor
                systemctl disable apparmor --now 2>/dev/null
                echo -e "${GREEN}✓ AppArmor 已停止并禁用。${NC}"
            elif systemctl list-unit-files | grep -q "^apparmor"; then
                echo -e "${GREEN}✓ AppArmor 已禁用。${NC}"
            else
                echo -e "${YELLOW}⚠ AppArmor 服务未找到，跳过。${NC}"
            fi

            echo -e "${GREEN}>>> UFW 与 AppArmor 处理完成。${NC}"
            ;;

        *)
            echo -e "${RED}✗ 不支持的操作系统：$OS_FAMILY${NC}"
            return 1
            ;;
    esac
}

# -------------------------- 启用额外软件仓库 -------------------------------
action_enable_extra_repos() {
    case "$OS_FAMILY" in
        rocky|centos|rhel)
            echo -e "${BLUE}>>> 正在启用 EPEL 软件仓库并更新缓存...${NC}"

            # 检查是否已安装 epel-release
            if dnf list installed epel-release &>/dev/null; then
                echo -e "${GREEN}✓ EPEL 仓库已启用。${NC}"
            else
                echo -e "${YELLOW}→ 正在安装 EPEL 仓库...${NC}"
                if dnf install -y epel-release; then
                    echo -e "${GREEN}✓ EPEL 仓库安装成功。${NC}"
                else
                    echo -e "${RED}✗ EPEL 仓库安装失败，请检查网络或系统配置。${NC}"
                    return 1
                fi
            fi

            # 更新元数据缓存
            echo -e "${YELLOW}→ 正在更新软件包缓存...${NC}"
            if dnf makecache --assumeyes; then
                echo -e "${GREEN}✓ 软件源缓存已更新。${NC}"
            else
                echo -e "${YELLOW}⚠ 缓存更新部分失败，但可能不影响使用。${NC}"
            fi

            echo -e "${GREEN}>>> EPEL 仓库启用完成。${NC}"
            ;;

        ubuntu|debian)
            echo -e "${BLUE}>>> 正在启用额外软件仓库并更新缓存...${NC}"

            # 启用 universe / multiverse（Ubuntu）或 contrib/non-free（Debian）
            # add-apt-repository 在 Debian 中可能不存在，先确保安装
            if ! command -v add-apt-repository >/dev/null; then
                echo -e "${YELLOW}→ 安装 software-properties-common...${NC}"
                apt install -y software-properties-common &>/dev/null
            fi

            # 启用扩展仓库
            echo -e "${YELLOW}→ 启用 universe 和 multiverse 仓库...${NC}"
            add-apt-repository -y universe &>/dev/null
            add-apt-repository -y multiverse &>/dev/null

            # 更新软件包列表
            echo -e "${YELLOW}→ 正在更新软件包缓存...${NC}"
            if apt update; then
                echo -e "${GREEN}✓ 软件源缓存已更新。${NC}"
            else
                echo -e "${RED}✗ 软件源更新失败，请检查网络或源配置。${NC}"
                return 1
            fi

            echo -e "${GREEN}>>> 额外软件仓库启用完成。${NC}"
            ;;

        *)
            echo -e "${RED}✗ 不支持的操作系统：$OS_FAMILY${NC}"
            return 1
            ;;
    esac
}

# -------------------------- 安装常用软件包 ----------------------------------
action_install_packages() {
    echo -e "${BLUE}>>> 正在安装常用软件包...${NC}"

    case "$OS_FAMILY" in
        rocky|centos|rhel)
            # 更新元数据缓存
            echo -e "${YELLOW}→ 正在更新软件包缓存...${NC}"
            if dnf makecache --assumeyes; then
                echo -e "${GREEN}✓ 软件源缓存已更新。${NC}"
            else
                echo -e "${YELLOW}⚠ 缓存更新失败，但可能不影响使用。${NC}"
            fi

            # 安装常用软件包
            echo -e "${YELLOW}→ 安装常用软件包...${NC}"
            if ! dnf install -y "${RHEL_PACKAGES[@]}"; then
                echo -e "${RED}✗ 部分软件包安装失败，请检查网络、仓库或包名。${NC}"
                return 1
            fi

            echo -e "${GREEN}✓ 已安装常用软件包如下：${NC}"
            printf "  ${CYAN}%s${NC}\n" "${RHEL_PACKAGES[@]}"

            # 提示是否更新其他软件包
            read -rp "$(echo -e "${YELLOW}→ 是否更新所有可升级的软件包？[y/N]: ${NC}")" upgrade_choice
            case "${upgrade_choice,,}" in
                y|yes)
                    if dnf upgrade -y; then
                        echo -e "${GREEN}✓ 所有软件包已更新完成。${NC}"
                    else
                        echo -e "${RED}✗ 软件包更新过程中出现错误。${NC}"
                    fi
                    ;;
                *)
                    echo -e "${GREEN}→ 跳过软件包更新。${NC}"
                    ;;
            esac
            ;;

        ubuntu|debian)
            # 更新软件包列表
            echo -e "${YELLOW}→ 正在更新软件包缓存...${NC}"
            if apt update; then
                echo -e "${GREEN}✓ 软件源缓存已更新。${NC}"
            else
                echo -e "${RED}✗ 软件源更新失败，请检查网络或源配置。${NC}"
                return 1
            fi

            # 安装常用软件包
            echo -e "${GREEN}→ 安装常用软件包...${NC}"
            if ! apt install -y "${DEBIAN_PACKAGES[@]}"; then
                echo -e "${RED}✗ 部分软件包安装失败，请检查网络、仓库或包名。${NC}"
                return 1
            fi

            echo -e "${GREEN}✓ 已安装常用软件包如下：${NC}"
            printf "  ${CYAN}%s${NC}\n" "${DEBIAN_PACKAGES[@]}"

            # 提示是否进行全系统软件包更新
            read -rp "$(echo -e "${YELLOW}→ 是否更新所有可升级的软件包？[y/N]: ${NC}")" upgrade_choice
            case "${upgrade_choice,,}" in
                y|yes)
                    if apt upgrade -y; then
                        echo -e "${GREEN}✓ 所有软件包已更新完成。${NC}"
                    else
                        echo -e "${RED}✗ 软件包更新过程中出现错误。${NC}"
                    fi
                    ;;
                *)
                    echo -e "${GREEN}→ 跳过软件包更新。${NC}"
                    ;;
            esac
            ;;

        *)
            echo -e "${RED}✗ 不支持的操作系统：$OS_FAMILY${NC}"
            return 1
            ;;
    esac

    echo -e "${GREEN}>>> 常用工具安装完成。${NC}"
}

# -------------------------- 安装常用软件包（非包管理工具） --------------------
action_install_packages_manual() {
    echo -e "${BLUE}>>> 正在安装常用软件包（非包管理工具方式）...${NC}"
    echo -e "${YELLOW}→ 本功能用于通过 curl 等官方安装脚本安装工具${NC}"
    echo

    # ====================== zoxide 智能目录跳转工具 （临时占位）======================
    echo -e "${YELLOW}→ 正在安装 zoxide（智能目录跳转工具）...（临时占位）${NC}"
    echo -e "${GREEN}>>> zoxide 安装与配置完成！（临时占位）${NC}"
    echo

    echo -e "${GREEN}>>> 非包管理工具常用软件安装流程执行完成。${NC}"
    echo -e "${YELLOW}提示：如安装了修改 shell 配置的工具，建议重新登录终端或执行 source ~/.bashrc 后生效。${NC}"
}

# -------------------------- 系统及软件配置优化 -------------------------------
action_optimize_config() {
    echo -e "${BLUE}>>> 正在优化系统及软件配置...${NC}"

    # --- 确定 cdnet 别名的目标路径 ---
    case "$OS_FAMILY" in
        rocky|centos|rhel)
            CDNET_PATH="/etc/NetworkManager/system-connections/"
            ;;
        ubuntu|debian)
            CDNET_PATH="/etc/netplan/"
            ;;
        *)
            echo -e "${YELLOW}⚠ 未知系统 $OS_FAMILY，cdnet 别名将指向 /etc/。${NC}"
            CDNET_PATH="/etc/"
            ;;
    esac

    echo -e "${YELLOW}→ 正在配置 Bash 增强功能（避免重复添加）...${NC}"

    # ====================== Bash 配置优化（防重复） ======================
    local bashrc="$TARGET_HOME/.bashrc"
    local added=false

    # 1. History 增强配置
    if ! grep -q "HISTTIMEFORMAT=" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << 'EOF'

# ========== history 增强 ==========
# 设置历史命令的时间格式：年-月-日 时:分:秒 用户名
export HISTTIMEFORMAT="%F %T $(whoami) "

# 实时追加历史记录，实现多终端共享
export PROMPT_COMMAND='history -a'

# 历史命令数量设置
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups
EOF
        added=true
        echo -e "${GREEN}✓ History 增强配置已添加${NC}"
    else
        echo -e "${GREEN}✓ History 增强配置已存在，跳过${NC}"
    fi

    # 2. 常用别名（cdnet）
    if ! grep -q "alias cdnet=" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << EOF

# ============ 常用别名 ============
alias cdnet='cd $CDNET_PATH'
EOF
        added=true
        echo -e "${GREEN}✓ cdnet 别名已添加${NC}"
    else
        echo -e "${GREEN}✓ cdnet 别名配置已存在，跳过${NC}"
    fi

    # 3. 命令行提示符 PS1
    if ! grep -q "export PS1=" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << 'EOF'

# =========== 命令行提示符 ===========
export PS1=" 💁 \[\033[0;32m\]\u\[\033[0m\] 💻 \[\033[0;33m\]\h\[\033[0m\] 📁 \[\033[0;35m\]\w\[\033[0m\]\n "
EOF
        added=true
        echo -e "${GREEN}✓ PS1 提示符已优化${NC}"
    else
        echo -e "${GREEN}✓ PS1 提示符配置已存在，跳过${NC}"
    fi

    # 4. LC_TIME 设置（24小时制）
    if ! grep -q "export LC_TIME=C" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << 'EOF'

# =========== 24小时制 ===========
export LC_TIME=C
EOF
        added=true
        echo -e "${GREEN}✓ LC_TIME 已设置为 24 小时制${NC}"
    else
        echo -e "${GREEN}✓ LC_TIME 配置已存在，跳过${NC}"
    fi

    # 5. zoxide 配置
    if ! grep -q "zoxide init bash" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << 'EOF'

# ========== zoxide 智能目录跳转 ==========
# 使用 z 命令快速跳转到常用目录（会根据使用习惯自动学习）
# 常用用法：
#   z <关键词>          # 模糊跳转
#   z -                 # 列出最近访问目录
#   z -i <关键词>       # 交互式选择
eval "$(zoxide init bash)"
EOF
        added=true
        echo -e "${GREEN}✓ zoxide 已自动添加到 ~/.bashrc${NC}"
    else
        echo -e "${GREEN}✓ zoxide 配置已存在，跳过${NC}"
    fi

    if [[ "$added" == false ]]; then
        echo -e "${GREEN}✓ Bash 配置均已存在，无需重复添加${NC}"
    fi

    # --- 配置 Vim（覆盖式，保持最新配置）---
    echo -e "${YELLOW}→ 正在配置 Vim...${NC}"
    cat > "$TARGET_HOME/.vimrc" << 'EOF'
" ========== Vim 优化配置 ==========
set number                " 显示行号
set expandtab             " 将 Tab 转为空格
set tabstop=4             " 1 个 Tab 显示为 4 个空格
set shiftwidth=4          " 自动缩进时使用 4 个空格
set autoindent            " 自动缩进
set softtabstop=4         " 按 Backspace 时删除 4 个空格
set cursorline            " 光标所在行显示下划线
set showmatch             " 匹配括号高亮
set paste                 " 保留格式
syntax on                 " 启用语法高亮
filetype plugin indent on " 按文件类型启用智能缩进
EOF
    echo -e "${GREEN}✓ Vim 配置已更新（覆盖模式）${NC}"

    # --- 设置时区 ---
    echo -e "${YELLOW}→ 正在设置系统时区...${NC}"
    timedatectl set-timezone Asia/Shanghai
    echo -e "${GREEN}✓ Asia/Shanghai 时区已更新${NC}"

    echo -e "${GREEN}>>> 系统及软件配置优化完成（重新登录终端或 source ~/.bashrc 生效）${NC}"
}

# -------------------------- 安装容器（Docker / Podman） -----------------------
action_install_docker() {
    local choice container_runtime

    echo -e "${BLUE}>>> 请选择要安装的容器运行时：${NC}"
    echo "    1) Docker (推荐通用场景)"
    echo "    2) Podman (无守护进程，兼容 Docker CLI)"
    echo "    3) 取消"
    read -p "请输入选项 [1-3]: " choice

    case "$choice" in
        1)
            container_runtime="docker"
            ;;
        2)
            container_runtime="podman"
            ;;
        3)
            echo -e "${YELLOW}→ 已取消安装。${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}✗ 无效选项，请重新运行此功能。${NC}"
            return 1
            ;;
    esac

    echo -e "${BLUE}>>> 正在安装容器运行时（$container_runtime）...${NC}"

    case "$OS_FAMILY" in
        rocky|centos|rhel)
            if [ "$container_runtime" = "docker" ]; then
                install_docker_rhel
            elif [ "$container_runtime" = "podman" ]; then
                install_podman_rhel
            fi
            ;;

        ubuntu|debian)
            if [ "$container_runtime" = "docker" ]; then
                install_docker_debian
            elif [ "$container_runtime" = "podman" ]; then
                install_podman_debian
            fi
            ;;

        *)
            echo -e "${RED}✗ 不支持的操作系统：$OS_FAMILY${NC}"
            return 1
            ;;
    esac
}

# -------------------------- RHEL 系容器安装 -------------------------------
install_docker_rhel() {
    echo -e "${YELLOW}→ 卸载旧版本 Docker / Podman（如有）...${NC}"
    # 忽略错误（若未安装则跳过）
    dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc 2>/dev/null || true

    echo -e "${YELLOW}→ 安装 dnf-plugins-core（提供 config-manager）...${NC}"
    if ! dnf -y install dnf-plugins-core; then
        echo -e "${RED}✗ 无法安装 dnf-plugins-core。${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ 添加 Docker 官方仓库...${NC}"
    if ! dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo; then
        echo -e "${RED}✗ 无法添加 Docker 仓库，请检查网络或系统版本兼容性。${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ 安装 Docker Engine 及相关组件...${NC}"
    if ! dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        echo -e "${RED}✗ Docker 安装失败。${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ 启动并启用 Docker 服务...${NC}"
    systemctl enable --now docker
    echo -e "${GREEN}>>> Docker 已成功安装并启动。${NC}"

    docker_ver=$(docker --version 2>/dev/null)
    compose_ver=$(docker compose version 2>/dev/null || echo "未检测到 docker compose 插件")
    echo -e "${YELLOW}${docker_ver}${NC}"
    echo -e "${YELLOW}${compose_ver}${NC}"
}

install_podman_rhel() {
    # 更新元数据缓存
    echo -e "${YELLOW}→ 正在更新软件包缓存...${NC}"
    if dnf makecache --assumeyes; then
        echo -e "${GREEN}✓ 软件源缓存已更新。${NC}"
    else
        echo -e "${YELLOW}⚠ 缓存更新失败，但可能不影响使用。${NC}"
    fi

    # 安装podman
    echo -e "${YELLOW}→ 安装 Podman...${NC}"
    if ! dnf install -y podman; then
        echo -e "${RED}✗ Podman 安装失败。${NC}"
        return 1
    fi

    # Podman 无需守护进程，但可验证
    echo -e "${GREEN}>>> Podman 已成功安装。${NC}"

    podman_ver=$(podman --version 2>/dev/null)
    echo -e "${YELLOW}${podman_ver}${NC}"
}

# -------------------------- Debian 系容器安装 -----------------------------
install_docker_debian() {
    echo -e "${YELLOW}→ 卸载旧版本 Docker / Podman 相关包（如有）...${NC}"
    # 完全按照官方命令：只移除已安装的冲突包
    apt remove -y $(dpkg --get-selections \
        docker.io docker-compose docker-compose-v2 docker-doc \
        podman-docker containerd runc 2>/dev/null | cut -f1) 2>/dev/null || true

    echo -e "${YELLOW}→ 更新 APT 软件包列表...${NC}"
    if ! apt update; then
        echo -e "${RED}✗ APT 更新失败。${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ 安装必要依赖...${NC}"
    if ! apt install -y ca-certificates curl; then
        echo -e "${RED}✗ 依赖安装失败。${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ 创建 keyrings 目录...${NC}"
    install -m 0755 -d /etc/apt/keyrings

    echo -e "${YELLOW}→ 下载并保存 Docker 官方 GPG 密钥（.asc 格式）...${NC}"
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
        echo -e "${RED}✗ 无法下载 Docker GPG 密钥。${NC}"
        return 1
    fi
    chmod a+r /etc/apt/keyrings/docker.asc

    echo -e "${YELLOW}→ 添加 Docker APT 仓库（使用 .sources DEB822 格式）...${NC}"
    # 使用官方推荐方式获取 Ubuntu 代号
    if ! . /etc/os-release && [ -n "${UBUNTU_CODENAME:-}" ]; then
        SUITE="$UBUNTU_CODENAME"
    elif [ -n "${VERSION_CODENAME:-}" ]; then
        SUITE="$VERSION_CODENAME"
    else
        echo -e "${RED}✗ 无法确定 Ubuntu 代号（$ID $VERSION_ID）。${NC}"
        return 1
    fi

    cat > /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $SUITE
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    # ！！！最重要的一步：添加源后立即更新索引！！！
    echo -e "${YELLOW}→ 更新 APT 索引（加载新添加的 Docker 源）...${NC}"
    if ! apt update; then
        echo -e "${RED}✗ apt update 失败，请检查网络或源是否可用${NC}"
        cat /etc/apt/sources.list.d/docker.list
        return 1
    fi

    echo -e "${YELLOW}→ 安装 Docker Engine 及相关组件...${NC}"
    if ! apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        echo -e "${RED}✗ Docker 安装失败。${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ 启动并启用 Docker 服务...${NC}"
    systemctl enable --now docker
    echo -e "${GREEN}>>> Docker 已成功安装并启动。${NC}"

    docker_ver=$(docker --version 2>/dev/null)
    compose_ver=$(docker compose version 2>/dev/null || echo "未检测到 docker compose 插件")
    echo -e "${YELLOW}${docker_ver}${NC}"
    echo -e "${YELLOW}${compose_ver}${NC}"
}

install_podman_debian() {
    # 更新软件包列表
    echo -e "${YELLOW}→ 正在更新软件包缓存...${NC}"
    if apt update; then
        echo -e "${GREEN}✓ 软件源缓存已更新。${NC}"
    else
        echo -e "${RED}✗ 软件源更新失败，请检查网络或源配置。${NC}"
        return 1
    fi

    # 安装podman
    echo -e "${YELLOW}→ 安装 Podman...${NC}"
    if ! apt install -y podman; then
        echo -e "${RED}✗ Podman 安装失败（Ubuntu 22.04+ 才有官方支持）。${NC}"
        return 1
    fi

    echo -e "${GREEN}>>> Podman 已成功安装。${NC}"

    podman_ver=$(podman --version 2>/dev/null)
    echo -e "${YELLOW}${podman_ver}${NC}"
}

# -------------------------- 重启系统 -----------------------------------------
action_reboot_system() {
    echo -e "${YELLOW}⚠ 即将重启系统，请确认所有重要操作已完成！${NC}"
    read -rp "$(echo -e "${RED}是否立即重启系统？[y/N]: ${NC}")" reboot_choice
    case "${reboot_choice,,}" in
        y|yes)
            echo -e "${BLUE}>>> 系统将在 5 秒后重启...${NC}"
            sleep 5
            reboot
            ;;
        *)
            echo -e "${GREEN}→ 已取消重启操作。${NC}"
            ;;
    esac
}

# ------------------------------ 主菜单 ----------------------------------------
main_menu() {
    while true; do
        echo -e "${YELLOW}=============== Linux 系统初始化菜单 ===============${NC}"
        echo "1) 关闭防火墙与安全机制"
        echo "2) 启用额外软件仓库"
        echo "3) 安装常用软件包（包管理工具安装）"
        echo "4) 安装常用软件包（非包管理工具安装）"
        echo "5) 系统及软件优化"
        echo "6) 安装容器"
        echo "7) 预留功能（未来扩展）"
        echo "r) 重启系统"
        echo "q) 退出脚本"
        echo -e "${YELLOW}====================================================${NC}"

        read -rp "请选择功能 [1-7/r/q]: " choice
        echo

        case "$choice" in
            1) action_disable_security ;;
            2) action_enable_extra_repos ;;
            3) action_install_packages ;;
            4) action_install_packages_manual ;;   # 新增
            5) action_optimize_config ;;
            6) action_install_docker ;;
            7) echo -e "${YELLOW}→ 功能7：预留，暂无操作。${NC}" ;;
            r|R)
                action_reboot_system ;;            # 新增
            q|Q)
                echo -e "${GREEN}已退出脚本。${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请输入 1-7 或 r/q。${NC}"
                ;;
        esac
        echo
    done
}

# ------------------------------ 启动程序 --------------------------------------
detect_os               # 检测系统类型
show_system_info        # 展示基本信息
main_menu               # 进入交互菜单
