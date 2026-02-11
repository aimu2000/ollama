#!/bin/bash

################################################################################
#                    OLLAMA 安装脚本 v1.0                                      #
#                    支持离线安装和在线下载                                      #
################################################################################
#
# 【使用方法】
#
# 方法1：本地有安装包（推荐）
#   1. 传输脚本和安装包到服务器
#      scp install_ollama.sh root@服务器IP:/tmp/
#      scp ollama-linux-amd64.tar.zst root@服务器IP:/tmp/
#
#   2. SSH连接到服务器
#      ssh root@服务器IP
#
#   3. 执行安装
#      cd /tmp
#      chmod +x install_ollama.sh
#      ./install_ollama.sh
#
# 方法2：纯在线安装（服务器有网络）
#   curl -fsSL https://raw.githubusercontent.com/你的用户名/install_ollama.sh | bash
#
# 方法3：手动在线下载安装包后安装
#   ./install_ollama.sh
#   (脚本会自动检测本地是否有安装包，没有则从GitHub下载)
#
# 【功能特性】
#   ✓ 自动检测本地安装包
#   ✓ 自动从GitHub下载最新版本
#   ✓ 支持指定版本安装
#   ✓ 智能处理已安装版本
#   ✓ 交互式确认和选择
#
# 【注意事项】
#   需要 sudo 权限
#   需要 curl（在线下载时）
#   需要 zstd 解压工具
#
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       OLLAMA 安装脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

OLLAMA_FILE="ollama-linux-amd64.tar.zst"
OLLAMA_VERSION=""

# 检测本地OLLAMA压缩包
check_local_file() {
    if [ -f "$OLLAMA_FILE" ]; then
        echo -e "${GREEN}✓ 发现本地安装文件:${NC} $OLLAMA_FILE"
        ls -lh "$OLLAMA_FILE"
        return 0
    else
        return 1
    fi
}

# 从GitHub下载
download_online() {
    echo ""
    echo -e "${YELLOW}未找到本地安装文件，选择下载方式:${NC}"
    echo "  [1] 从GitHub下载最新版本"
    echo "  [2] 从GitHub下载指定版本"
    echo "  [3] 退出"
    read -p "请选择 [1/2/3]: " -n 1 -r
    echo ""

    case $REPLY in
        1)
            echo -e "${BLUE}>>> 获取最新版本...${NC}"
            LATEST_VERSION=$(curl -sL https://api.github.com/repos/ollama/ollama/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
            if [ -z "$LATEST_VERSION" ]; then
                echo -e "${RED}!!! 无法获取最新版本${NC}"
                exit 1
            fi
            echo -e "${GREEN}最新版本: ${LATEST_VERSION}${NC}"
            DOWNLOAD_URL="https://github.com/ollama/ollama/releases/download/${LATEST_VERSION}/${OLLAMA_FILE}"
            ;;
        2)
            echo -n "请输入版本号（如 0.15.6）: "
            read OLLAMA_VERSION
            if [ -z "$OLLAMA_VERSION" ]; then
                echo -e "${RED}!!! 版本号不能为空${NC}"
                exit 1
            fi
            DOWNLOAD_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/${OLLAMA_FILE}"
            ;;
        3)
            echo "已退出。"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac

    echo -e "${BLUE}>>> 下载地址: ${DOWNLOAD_URL}${NC}"

    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}!!! 需要curl，请先安装: sudo apt install curl${NC}"
        exit 1
    fi

    echo -e "${BLUE}>>> 下载中...${NC}"
    curl -L -o "$OLLAMA_FILE" "$DOWNLOAD_URL"

    if [ -f "$OLLAMA_FILE" ]; then
        echo -e "${GREEN}✓ 下载完成${NC}"
        ls -lh "$OLLAMA_FILE"
    else
        echo -e "${RED}!!! 下载失败${NC}"
        exit 1
    fi
}

# 确认是否继续
confirm_install() {
    echo ""
    read -p "是否继续安装? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消安装。"
        exit 0
    fi
}

# 卸载旧版本
uninstall_old() {
    echo ""
    echo -e "${YELLOW}检测到旧版本OLLAMA，是否卸载?${NC}"
    echo "  [1] 是，卸载后重新安装"
    echo "  [2] 否，保留旧版本"
    echo "  [3] 仅更新文件"
    read -p "请选择 [1/2/3]: " -n 1 -r
    echo ""

    case $REPLY in
        1)
            echo -e "${RED}>>> 卸载旧版本...${NC}"
            sudo systemctl stop ollama 2>/dev/null || true
            sudo rm -rf /usr/local/bin/ollama /usr/local/lib/ollama /etc/systemd/system/ollama.service 2>/dev/null || true
            echo -e "${GREEN}✓ 旧版本已卸载${NC}"
            return 0
            ;;
        2)
            echo "保留旧版本，跳过安装。"
            exit 0
            ;;
        3)
            echo -e "${YELLOW}>>> 仅更新文件...${NC}"
            sudo systemctl stop ollama 2>/dev/null || true
            sudo rm -rf /usr/local/bin/ollama /usr/local/lib/ollama 2>/dev/null || true
            return 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac
}

# 安装OLLAMA
install_ollama() {
    echo ""
    echo -e "${GREEN}>>> 开始安装OLLAMA...${NC}"
    echo ""

    # 创建目录
    sudo mkdir -p /usr/local/bin /usr/local/lib/ollama

    # 解压
    echo ">>> 解压中..."
    sudo tar -I zstd -xf "$OLLAMA_FILE" -C /usr/local --overwrite 2>/dev/null || \
    sudo tar -I zstd -xf "$OLLAMA_FILE" -C /usr/local

    # 验证文件
    if [ ! -f /usr/local/bin/ollama ]; then
        echo -e "${RED}!!! 错误: ollama主程序未找到${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 文件解压完成${NC}"
    ls -la /usr/local/bin/ollama

    # 创建用户
    echo ""
    echo ">>> 创建用户..."
    id ollama >/dev/null 2>&1 || sudo useradd -r -s /sbin/nologin -U -m -d /usr/share/ollama ollama
    sudo usermod -a -G video,render ollama
    echo -e "${GREEN}✓ 用户创建完成${NC}"

    # 创建服务
    echo ""
    echo ">>> 创建systemd服务..."
    sudo tee /etc/systemd/system/ollama.service > /dev/null <<'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="LD_LIBRARY_PATH=/usr/local/lib/ollama"

[Install]
WantedBy=default.target
EOF
    echo -e "${GREEN}✓ 服务配置完成${NC}"

    # 启动服务
    echo ""
    echo ">>> 启动服务..."
    sudo systemctl daemon-reload
    sudo systemctl enable ollama
    sudo systemctl start ollama

    # 等待启动
    sleep 2

    # 验证
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}       安装完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    /usr/local/bin/ollama --version
    echo ""
    sudo systemctl status ollama --no-pager
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  下载模型: ollama pull qwen2.5:7b"
    echo "  查看模型: ollama list"
    echo "  运行模型: ollama run qwen2.5:7b"
    echo "  服务状态: sudo systemctl status ollama"
    echo "  重启服务: sudo systemctl restart ollama"
    echo "  停止服务: sudo systemctl stop ollama"
}

# 主程序
main() {
    # 检查本地文件
    if check_local_file; then
        echo -e "${YELLOW}是否使用本地文件? [Y/n]${NC}"
        read -p "请选择: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            download_online
        fi
    else
        download_online
    fi

    # 检查是否已安装
    if command -v ollama >/dev/null 2>&1 || [ -f /usr/local/bin/ollama ]; then
        echo -e "${YELLOW}检测到OLLAMA已安装${NC}"
        confirm_install
        uninstall_old
    else
        confirm_install
    fi

    # 执行安装
    install_ollama
}

main "$@"
