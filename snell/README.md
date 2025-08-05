# Snell 一键安装脚本

Linux 系统自动安装配置 Snell 代理服务器

## 快速安装
```bash
# 一键安装（默认 v5.0.0）
curl -fsSL https://raw.githubusercontent.com/youtonghy/Shell/main/snell/install_snell.sh | bash

# 自定义版本
wget -O install_snell.sh https://raw.githubusercontent.com/youtonghy/Shell/main/snell/install_snell.sh
chmod +x install_snell.sh && ./install_snell.sh
```

## 功能
- 自动下载安装 Snell Server
- 生成随机端口和 PSK 密钥  
- 配置 systemd 服务并开机自启
- 输出 Surge 客户端配置

## 系统要求
- Linux (Ubuntu/Debian/CentOS)
- sudo 权限
- wget & unzip

## 服务管理
```bash
sudo systemctl {start|stop|restart|status|enable|disable} snell
sudo journalctl -u snell -f
```

## 文件位置
- 配置: `/etc/snell/snell-server.conf`
- 服务: `/lib/systemd/system/snell.service`
- 程序: `/usr/local/bin/snell-server`