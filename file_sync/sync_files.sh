#!/bin/bash

# 文件同步脚本：将A目录中存在但B目录中不存在的文件复制到B目录
# 用法: ./sync_files.sh <源目录A> <目标目录B>

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数数量
if [ $# -ne 2 ]; then
    echo -e "${RED}错误: 需要提供两个参数${NC}"
    echo "用法: $0 <源目录A> <目标目录B>"
    exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}错误: 源目录 '$SOURCE_DIR' 不存在${NC}"
    exit 1
fi

# 如果目标目录不存在，创建它
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}目标目录 '$TARGET_DIR' 不存在，正在创建...${NC}"
    mkdir -p "$TARGET_DIR"
fi

# 统计变量
copied_count=0
skipped_count=0

echo -e "${GREEN}开始同步文件...${NC}"
echo "源目录: $SOURCE_DIR"
echo "目标目录: $TARGET_DIR"
echo "----------------------------------------"

# 使用find遍历源目录中的所有文件
while IFS= read -r -d '' source_file; do
    # 获取相对路径
    relative_path="${source_file#$SOURCE_DIR/}"
    target_file="$TARGET_DIR/$relative_path"
    
    # 检查目标文件是否存在
    if [ ! -e "$target_file" ]; then
        # 创建目标文件的目录结构
        target_dir=$(dirname "$target_file")
        mkdir -p "$target_dir"
        
        # 复制文件
        cp -p "$source_file" "$target_file"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[已复制]${NC} $relative_path"
            ((copied_count++))
        else
            echo -e "${RED}[失败]${NC} $relative_path"
        fi
    else
        ((skipped_count++))
    fi
done < <(find "$SOURCE_DIR" -type f -print0)

echo "----------------------------------------"
echo -e "${GREEN}同步完成！${NC}"
echo "已复制文件数: $copied_count"
echo "已存在文件数: $skipped_count"
