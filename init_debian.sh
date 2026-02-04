#!/bin/bash
# init_debian.sh
# Debian 13 初始化脚本
# 包含功能：系统更新、安装常用软件、Vim 中文配置、安装 Docker (无人值守)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
   log_error "该脚本必须以 root 身份运行，请使用 sudo 执行或切换到 root 用户。"
   exit 1
fi

echo -e "========================================"
echo -e "  Debian 13 系统初始化脚本开始执行"
echo -e "========================================"

# 步骤 1: 系统更新
echo -e "\n----------------------------------------"
log_info "步骤 1: 系统更新与升级"
echo -e "----------------------------------------"

log_info "正在更新软件包列表 (apt update)..."
apt update -y

log_info "正在升级已安装软件包 (apt upgrade)..."
apt upgrade -y

log_info "系统更新完成。"

# 步骤 2: 安装常用软件
echo -e "\n----------------------------------------"
log_info "步骤 2: 安装常用软件"
echo -e "----------------------------------------"

# 定义需要安装的软件列表
SOFTWARE_LIST=(
    "vim"
    "curl"
    "wget"
    "netcat-openbsd"
    "git"
)

log_info "即将安装的软件列表: ${SOFTWARE_LIST[*]}"

for software in "${SOFTWARE_LIST[@]}"; do
    if ! command -v "$software" &> /dev/null; then
        log_info "正在安装 $software ..."
        apt install -y "$software"
    else
        log_warn "$software 已经安装，跳过。"
    fi
done

# 配置 Vim 中文支持
log_info "正在为 Vim 配置中文支持..."
VIMRC_FILE="$HOME/.vimrc"

# 检查是否已配置
if [ -f "$VIMRC_FILE" ] && grep -q "Added by init_debian.sh" "$VIMRC_FILE"; then
    log_warn "Vim 中文配置已存在，跳过。"
else
    # 备份原配置（如果存在）
    if [ -f "$VIMRC_FILE" ]; then
        cp "$VIMRC_FILE" "${VIMRC_FILE}.bak.$(date +%F_%T)"
        log_info "已备份原 .vimrc 文件。"
    fi
    
    # 写入新配置
    cat >> "$VIMRC_FILE" <<EOF
    
" --- Added by init_debian.sh for Chinese Support ---
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,gb18030,gbk,gb2312,cp936,big5,euc-jp,euc-kr,latin1
set termencoding=utf-8
" ---------------------------------------------------
EOF

    log_info "Vim 中文配置已写入到 $VIMRC_FILE"
fi




# 检查网络连通性函数
check_domain() {
    local domain=$1
    local port=${2:-443}
    
    # 简单的参数校验
    if [ -z "$domain" ]; then
        return 0
    fi

    log_info "正在检查网络连通性: $domain:$port"
    if nc -vz -w 5 "$domain" "$port" &> /dev/null; then
        log_info "网络通畅: $domain"
    else
        log_error "网络不可达: $domain (端口: $port)"
        log_error "请检查网络连接或更换 Docker 源。"
        exit 1
    fi
}

# 步骤 3: 安装 Docker
echo -e "\n----------------------------------------"
log_info "步骤 3: 安装 Docker (LinuxMirrors 无人值守模式)"
echo -e "----------------------------------------"

# 参数配置
DOCKER_SOURCE="mirrors.ustc.edu.cn/docker-ce"     # 中科大 Docker CE 源
DOCKER_REGISTRY="docker.1ms.run"                  # 毫秒镜像加速
PROTOCOL="http"                                   # 协议
INSTALL_LATEST="true"
CLOSE_FIREWALL="false"

if command -v docker &> /dev/null; then
    log_warn "Docker 似乎已安装，跳过安装步骤。"
else
    log_info "正在下载并执行 Docker 安装脚本..."
    log_info "Docker CE 源: $DOCKER_SOURCE"
    log_info "镜像仓库加速: $DOCKER_REGISTRY"
    
    # 解析并检查 DOCKER_SOURCE 的域名 (去除路径)
    SOURCE_DOMAIN=$(echo "$DOCKER_SOURCE" | cut -d'/' -f1)
    
    # 检查官方源/镜像源连通性
    check_domain "$SOURCE_DOMAIN"
    check_domain "$DOCKER_REGISTRY"
    
    # 执行无人值守安装
    bash <(curl -sSL https://linuxmirrors.cn/docker.sh) \
        --source "$DOCKER_SOURCE" \
        --source-registry "$DOCKER_REGISTRY" \
        --protocol "$PROTOCOL" \
        --use-intranet-source false \
        --install-latest "$INSTALL_LATEST" \
        --close-firewall "$CLOSE_FIREWALL" \
        --clean-screen false \
        --pure-mode \
        --ignore-backup-tips
fi

log_info "Docker 安装流程结束。"

# 脚本收尾
echo -e "\n========================================"
log_info "初始化脚本执行完毕！"
echo -e "========================================"

echo -e "\n[环境信息]"
if command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker Version:${NC}"
    docker --version
    echo -e "${YELLOW}Docker Compose Version:${NC}"
    docker compose version
else
    log_error "Docker 未能成功安装，请检查日志。"
fi

echo -e "${YELLOW}Vim Version:${NC}"
vim --version | head -n 1

echo -e "\n喵，任务完成。"
