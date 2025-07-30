# Snell 服务器一键安装脚本

这是一个用于自动安装和配置 Snell 代理服务器的一键安装脚本。支持 Linux 系统，自动下载、安装、配置并启动 Snell 服务器。

## ✨ 功能特性

- 🚀 **一键安装**: 自动下载并安装 Snell Server v5.0.0
- 🔧 **自动配置**: 自动生成随机端口和 PSK 密钥
- 🔄 **服务管理**: 自动设置 systemd 服务并开机自启
- 🌐 **IP 检测**: 自动获取服务器公网 IP 地址
- 📋 **配置生成**: 自动生成 Surge 客户端配置格式
- ✅ **依赖检查**: 检查并提示必要的依赖工具

## 📋 系统要求

- Linux 系统 (Ubuntu/Debian/CentOS 等)
- 需要 sudo 权限
- 需要安装 `wget` 和 `unzip` 工具

## 🚀 快速开始

### 方法一：直接执行（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/youtonghy/Shell/refs/heads/main/snell/install_snell.sh | bash
```

**优点：**
- 最简洁，只需一条命令
- 不会在本地留下临时文件
- 直接通过管道执行

**⚠️ 注意：**
- 使用此方法时会自动使用默认版本号 `5.0.0`
- 脚本无法在管道执行时询问用户输入版本号
- 如需自定义版本号，请使用方法二或方法三

### 方法二：下载后执行（使用 curl）

```bash
curl -fsSL https://raw.githubusercontent.com/youtonghy/Shell/refs/heads/main/snell/install_snell.sh -o install_snell.sh && chmod +x install_snell.sh && ./install_snell.sh
```

**优点：**
- 支持自定义版本号输入
- 可以查看脚本内容后再执行
- 更安全的执行方式

### 方法三：下载后执行（使用 wget）

```bash
wget -O install_snell.sh https://raw.githubusercontent.com/youtonghy/Shell/refs/heads/main/snell/install_snell.sh && chmod +x install_snell.sh && ./install_snell.sh
```

**优点：**
- 支持自定义版本号输入
- 可以查看脚本内容后再执行
- 更安全的执行方式

### 方法四：本地执行

如果已经克隆了仓库：

```bash
cd Shell/snell
chmod +x install_snell.sh
./install_snell.sh
```

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `install_snell.sh` | 主安装脚本，负责下载、安装和配置 Snell 服务器 |
| `snell.service` | systemd 服务配置文件，用于管理 Snell 服务 |

## 🛠️ 安装过程

脚本会自动执行以下步骤：

1. **环境检查**: 检查 `wget` 和 `unzip` 是否已安装
2. **下载程序**: 从官方源下载 Snell Server v5.0.0
3. **安装程序**: 解压并安装到 `/usr/local/bin/`
4. **创建配置**: 生成随机端口和 PSK 密钥
5. **服务配置**: 下载并配置 systemd 服务文件
6. **启动服务**: 启动服务并设置开机自启
7. **获取配置**: 自动生成客户端配置信息

## 📊 服务管理

安装完成后，您可以使用以下命令管理 Snell 服务：

```bash
# 启动服务
sudo systemctl start snell

# 停止服务
sudo systemctl stop snell

# 重启服务
sudo systemctl restart snell

# 查看服务状态
sudo systemctl status snell

# 开机自启
sudo systemctl enable snell

# 禁用开机自启
sudo systemctl disable snell

# 查看服务日志
sudo journalctl -u snell -f
```

## 📝 配置文件位置

- **服务器配置**: `/etc/snell/snell-server.conf`
- **服务文件**: `/lib/systemd/system/snell.service`
- **程序位置**: `/usr/local/bin/snell-server`

## 🔧 客户端配置

安装完成后，脚本会自动输出 Surge 客户端配置格式：

```
==== Surge配置格式 ====
Snell V5 = snell, 服务器IP, 端口, psk=密钥, version=5
========================
```

将此配置添加到您的 Surge 配置文件中即可使用。

## 🎯 命令参数说明

### curl 参数
- `-f`: 失败时不显示 HTTP 错误
- `-s`: 静默模式，不显示进度
- `-S`: 出错时显示错误信息
- `-L`: 跟随重定向

### 脚本执行流程
- `&&`: 前一个命令成功后才执行下一个命令
- 确保每个步骤都成功完成

## ❗ 注意事项

1. **权限要求**: 脚本需要 sudo 权限来安装系统文件
2. **防火墙**: 确保服务器防火墙允许 Snell 端口通行
3. **依赖检查**: 脚本会自动检查依赖，请根据提示安装缺失工具
4. **重复安装**: 重复运行脚本会覆盖现有配置并生成新的端口和密钥
5. **版本号选择**: 
   - 使用 `curl ... | bash` 管道执行时，脚本的标准输入被占用，无法读取用户输入
   - 此时会自动使用默认版本号 `5.0.0`
   - 如需自定义版本号，请先下载脚本到本地再执行

## 🔧 故障排除

### 权限错误
```bash
# 确保具有 sudo 权限
sudo -v
```

### 依赖缺失
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install wget unzip

# CentOS/RHEL
sudo yum install wget unzip
```

### 服务状态检查
```bash
# 检查服务是否正在运行
sudo systemctl status snell

# 查看详细日志
sudo journalctl -u snell --no-pager
```

### 版本号自定义
如果需要安装特定版本的 Snell Server：

```bash
# 方法1: 先下载脚本再执行
wget -O install_snell.sh https://raw.githubusercontent.com/youtonghy/Shell/refs/heads/main/snell/install_snell.sh
chmod +x install_snell.sh
./install_snell.sh
# 按提示输入所需版本号，如：4.0.1

# 方法2: 使用环境变量 (需要修改脚本支持)
# SNELL_VERSION=4.0.1 ./install_snell.sh
```



## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

---

**⭐ 如果这个项目对您有帮助，请给个 Star！** 