#!/bin/sh
# 使用 set -e 命令，确保脚本在任何命令执行失败时立即退出
set -e

# 定义配置文件和默认配置文件的路径
CONFIG_FILE="/app/data/config.yml"
DEFAULT_CONFIG="/app/config.yml.default"
DATA_DIR="/app/data"
WEB_DAV_FILE="$DATA_DIR/data.mix_dav"
HISTORY_FILE="$DATA_DIR/history.mix_list"

# 检查数据卷中是否已存在配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating default configuration at $CONFIG_FILE"
    # 如果不存在，就从镜像中复制默认配置过去
    cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
fi

# 确保数据目录存在
mkdir -p "$DATA_DIR"

# 检查并创建 data.mix_dav 文件
if [ ! -f "$WEB_DAV_FILE" ]; then
    echo "WebDAV data file not found. Creating empty file at $WEB_DAV_FILE"
    touch "$WEB_DAV_FILE"
fi

# 检查并创建 history.mix_list 文件
if [ ! -f "$HISTORY_FILE" ]; then
    echo "History file not found. Creating empty file at $HISTORY_FILE"
    touch "$HISTORY_FILE"
fi

# 使用 exec 来执行 Java 应用。
# 这会让 Java 进程替换掉 shell 进程，成为容器的主进程 (PID 1)，
# 从而能够正确地接收和处理来自 Docker 的停止信号 (如 SIGTERM)。
cd "$DATA_DIR"
exec java -jar ../app.jar --spring.config.location=file:"$CONFIG_FILE"
