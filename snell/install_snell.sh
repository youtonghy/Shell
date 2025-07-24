#!/bin/bash

# Snell服务器安装脚本
echo "开始下载Snell服务器..."

# 设置文件名和URL
FILENAME="snell-server-v5.0.0-linux-amd64.zip"
URL="https://dl.nssurge.com/snell/snell-server-v5.0.0-linux-amd64.zip"

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

echo "Snell服务器安装完成！"
echo "您可以使用以下命令运行: snell-server" 