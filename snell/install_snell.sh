#!/bin/bash

# Snell服务器安装脚本
echo "开始下载Snell服务器..."

# 检测系统架构
ARCH=$(uname -m)
echo "检测到系统架构: $ARCH"

# 根据架构设置下载URL和文件名
case $ARCH in
    x86_64|amd64)
        ARCH_SUFFIX="amd64"
        ;;
    armv7l|arm)
        ARCH_SUFFIX="armv7l"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="aarch64"
        ;;
    i386|i686)
        ARCH_SUFFIX="i386"
        ;;
    *)
        echo "错误: 不支持的系统架构 $ARCH"
        echo "支持的架构: x86_64/amd64, armv7l/arm, aarch64/arm64, i386/i686"
        exit 1
        ;;
esac

echo "使用架构后缀: $ARCH_SUFFIX"

# 设置默认版本号
DEFAULT_VERSION="5.0.0"
DEFAULT_VERSION_SHORT="5"

# 询问用户输入版本号
echo ""
echo "请输入Snell服务器版本号 (默认: $DEFAULT_VERSION):"
read -p "版本号: " USER_VERSION

# 如果用户输入为空，使用默认版本号
if [ -z "$USER_VERSION" ]; then
    SNELL_VERSION="$DEFAULT_VERSION"
    VERSION="$DEFAULT_VERSION_SHORT"
    echo "使用默认版本号: $SNELL_VERSION"
else
    SNELL_VERSION="$USER_VERSION"
    # 提取主版本号（如5.0.0 -> 5）
    VERSION=$(echo "$SNELL_VERSION" | cut -d'.' -f1)
    echo "使用指定版本号: $SNELL_VERSION"
fi

# 设置文件名和URL
FILENAME="snell-server-v${SNELL_VERSION}-linux-${ARCH_SUFFIX}.zip"
URL="https://dl.nssurge.com/snell/snell-server-v${SNELL_VERSION}-linux-${ARCH_SUFFIX}.zip"
SERVICE_URL="https://raw.githubusercontent.com/youtonghy/Shell/refs/heads/main/snell/snell.service"

echo "下载文件: $FILENAME"
echo "下载地址: $URL"

# 检查wget是否可用
if ! command -v wget &> /dev/null; then
    echo "错误: wget未安装。请先安装wget。"
    exit 1
fi

# 检查unzip是否可用
if ! command -v unzip &> /dev/null; then
    echo "错误: unzip未安装。请先安装unzip。"
    exit 1
fi

# 下载文件
echo "正在从 $URL 下载文件..."
if wget "$URL" -O "$FILENAME"; then
    echo "下载完成: $FILENAME"
else
    echo "错误: 下载失败"
    exit 1
fi

# 检查下载的文件是否存在
if [ ! -f "$FILENAME" ]; then
    echo "错误: 下载的文件不存在"
    exit 1
fi

# 删除之前的snell-server
if [ -f "/usr/local/bin/snell-server" ]; then
    echo "删除之前的snell-server..."
    sudo rm -f /usr/local/bin/snell-server
fi

# 使用sudo解压文件到/usr/local/bin
echo "正在解压文件到 /usr/local/bin..."
if sudo unzip "$FILENAME" -d /usr/local/bin; then
    echo "解压完成"
else
    echo "错误: 解压失败"
    exit 1
fi

# 设置执行权限
echo "设置执行权限..."
sudo chmod +x /usr/local/bin/snell-server

# 删除下载的zip文件
echo "清理下载的文件..."
if rm "$FILENAME"; then
    echo "已删除下载的文件: $FILENAME"
else
    echo "警告: 无法删除文件 $FILENAME"
fi

# 创建配置文件目录
echo "创建配置文件目录..."
sudo mkdir -p /etc/snell
sudo chmod 755 /etc/snell

# 创建配置文件
echo "创建配置文件..."
echo "使用向导生成Snell配置文件..."
echo "y" | sudo /usr/local/bin/snell-server --wizard -c /etc/snell/snell-server.conf

# 删除之前的snell.service
if [ -f "/lib/systemd/system/snell.service" ]; then
    echo "删除之前的snell.service..."
    sudo rm -f /lib/systemd/system/snell.service
fi

# 下载systemd服务文件
echo "正在下载systemd服务文件..."
if sudo wget "$SERVICE_URL" -O /lib/systemd/system/snell.service; then
    echo "systemd服务文件下载完成"
else
    echo "错误: systemd服务文件下载失败"
    exit 1
fi

# 重新加载systemd配置
echo "重新加载systemd配置..."
sudo systemctl daemon-reload

# 启动服务
echo "启动Snell服务..."
sudo systemctl restart snell

# 设置开机自启
echo "设置开机自启..."
sudo systemctl enable snell

# 导入Surge
echo "导入Surge配置..."

echo "Snell服务器安装完成！"
echo "您可以使用以下命令管理服务:"
echo "  启动服务: sudo systemctl start snell"
echo "  停止服务: sudo systemctl stop snell"
echo "  开机自启: sudo systemctl enable snell"
echo "  查看状态: sudo systemctl status snell"

# 解析snell配置文件
CONFIG_FILE="/etc/snell/snell-server.conf"
if [ -f "$CONFIG_FILE" ]; then
    # 获取监听地址和端口
    LISTEN=$(grep "^listen" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    # 获取PSK密钥
    PSK=$(grep "^psk" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    
    # 提取IP地址和端口
    if [[ $LISTEN == *":"* ]]; then
        IFS=':' read -r IP PORT <<< "$LISTEN"
    else
        IP="0.0.0.0"
        PORT="$LISTEN"
    fi
    
    # 如果IP是0.0.0.0，使用curl ip.sb获取公网IP地址
    if [ "$IP" = "0.0.0.0" ]; then
        echo "检测到监听地址为0.0.0.0，正在获取公网IP地址..."
        PUBLIC_IP=$(curl -s -4 ip.sb)
        if [ -n "$PUBLIC_IP" ]; then
            IP="$PUBLIC_IP"
            echo "获取到公网IP地址: $IP"
        else
            IP="YOUR_SERVER_IP"
            echo "警告: 无法获取公网IP地址，请手动替换YOUR_SERVER_IP"
        fi
    fi
    
    # 输出Surge格式配置
    echo ""
    echo "==== Surge配置格式 ===="
    echo "Snell V$VERSION = snell, $IP, $PORT, psk=$PSK, version=$VERSION"
    echo "========================"
    echo ""
    echo "请将上述配置添加到您的Surge配置文件中"
    if [ "$IP" = "YOUR_SERVER_IP" ]; then
        echo "注意: 请将YOUR_SERVER_IP替换为您的实际服务器IP地址"
    fi
else
    echo "错误: 配置文件 $CONFIG_FILE 不存在"
fi




