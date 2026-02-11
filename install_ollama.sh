#!/bin/bash

# OLLAMA 离线安装脚本
# 支持交互式操作和本地文件安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       OLLAMA 离线安装脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检测脚本执行位置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_FILE="ollama-linux-amd64.tar.zst"

# 检测OLLAMA压缩包
check_file() {
    if [ -f "$SCRIPT_DIR/$OLLAMA_FILE" ]; then
        echo -e "${GREEN}✓ 发现本地安装文件:${NC} $SCRIPT_DIR/$OLLAMA_FILE"
        return 0
    elif [ -f "$OLLAMA_FILE" ]; then
        echo -e "${GREEN}✓ 发现本地安装文件:${NC} $OLLAMA_FILE"
        return 0
    else
        echo -e "${RED}✗ 未找到 $OLLAMA_FILE${NC}"
        echo ""
        echo "请将 $OLLAMA_FILE 放到以下位置之一："
        echo "  1. 当前目录: $(pwd)/$OLLAMA_FILE"
        echo "  2. 脚本同目录: $SCRIPT_DIR/$OLLAMA_FILE"
        echo ""
        echo "然后重新运行此脚本。"
        return 1
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
    echo "  [3] 仅更新压缩包文件"
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
            echo "保留旧版本，跳过卸载。"
            return 0
            ;;
        3)
            echo -e "${YELLOW}>>> 仅更新文件...${NC}"
            sudo systemctl stop ollama 2>/dev/null || true
            sudo rm -rf /usr/local/bin/ollama /usr/local/lib/ollama 2>/dev/null || true
            return 0
            ;;
        *)
            echo -e "${RED}无效选择，取消安装。${NC}"
            exit 1
            ;;
    esac
}

# 安装OLLAMA
install_ollama() {
    # 确定压缩包路径
    if [ -f "$SCRIPT_DIR/$OLLAMA_FILE" ]; then
        TARBALL="$SCRIPT_DIR/$OLLAMA_FILE"
    else
        TARBALL="$OLLAMA_FILE"
    fi

    echo ""
    echo -e "${GREEN}>>> 开始安装OLLAMA...${NC}"
    echo ">>> 使用文件: $TARBALL"
    echo ""

    # 创建目录
    sudo mkdir -p /usr/local/bin /usr/local/lib/ollama

    # 解压
    echo ">>> 解压中..."
    sudo tar -I zstd -xf "$TARBALL" -C /usr/local --overwrite 2>/dev/null || \
    sudo tar -I zstd -xf "$TARBALL" -C /usr/local

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
    # 检查文件
    if ! check_file; then
        exit 1
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
