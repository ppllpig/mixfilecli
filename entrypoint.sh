#!/bin/sh
# 使用 set -e 命令，确保脚本在任何命令执行失败时立即退出
set -e

# 定义配置文件和默认配置文件的路径
CONFIG_FILE="/app/data/config.yml"
DEFAULT_CONFIG="/app/config.yml.default"
DATA_DIR="/app/data"

# --- 初始化阶段 ---
echo "Initializing container..."

# 1. 检查数据卷中是否已存在配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating default configuration at $CONFIG_FILE"
    # 如果不存在，就从镜像中复制默认配置过去
    cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
fi

# 2. 确保数据目录存在
mkdir -p "$DATA_DIR"

# 3. 检查并创建 data.mix_dav 文件
WEB_DAV_FILE="$DATA_DIR/data.mix_dav"
if [ ! -f "$WEB_DAV_FILE" ]; then
    echo "WebDAV data file not found. Creating initial empty GZIP file at $WEB_DAV_FILE"
    echo '{}' | gzip > "$WEB_DAV_FILE"
fi

# 4. 检查并创建 history.mix_list 文件
HISTORY_FILE="$DATA_DIR/history.mix_list"
if [ ! -f "$HISTORY_FILE" ]; then
    echo "History file not found. Creating initial empty GZIP file at $HISTORY_FILE"
    echo '[]' | gzip > "$HISTORY_FILE"
fi

# --- 运行阶段 ---
# 切换到数据目录，这对于应用可能产生相对路径的文件很重要
cd "$DATA_DIR"

echo "Initialization complete. Starting Java application..."

# 使用 exec 将控制权完全交给 Java 进程。
# 如果 Java 应用失败，整个容器会退出，然后 Docker 的重启策略会接管。
# 使用反斜杠 \ 将长命令分行，提高可读性。
exec /opt/java/openjdk/bin/java \
    -XX:+UseZGC \
    -XX:ZUncommitDelay=10 \
    -XX:MaxHeapSize=2g \
    -jar ../app.jar \
    --spring.config.location=file:"$CONFIG_FILE"
