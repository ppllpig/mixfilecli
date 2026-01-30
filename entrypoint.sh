#!/bin/sh
# 使用 set -e 命令，确保脚本在任何命令执行失败时立即退出
set -e

# =================================================================
#                         变量定义 (来自您的脚本)
# =================================================================
CONFIG_FILE="/app/data/config.yml"
DEFAULT_CONFIG="/app/config.yml.default"
DATA_DIR="/app/data"

# =================================================================
#                     初始化阶段 (来自您的脚本, 完全保留)
# =================================================================
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

# =================================================================
#          【新增】智能内存检测逻辑
# =================================================================
# Java 最大堆大小通常设置为容器内存限制的 75%
HEAP_PERCENTAGE=75
# 使用您原脚本中的 2g 作为未设置内存限制时的默认值
DEFAULT_HEAP_PARAM="-XX:MaxHeapSize=2g"
HEAP_PARAM=""

# 尝试从 Cgroup v2/v1 获取内存限制
if [ -f "/sys/fs/cgroup/memory.max" ] && [ "$(cat /sys/fs/cgroup/memory.max)" != "max" ]; then
    CONTAINER_MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory.max)
    CGROUP_VERSION="v2"
elif [ -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]; then
    CONTAINER_MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    CGROUP_VERSION="v1"
fi

# 如果成功获取到内存限制，则进行计算
if [ -n "$CONTAINER_MEMORY_LIMIT" ] && [ "$CONTAINER_MEMORY_LIMIT" -lt "1000000000000000" ]; then
    # 使用 awk 来进行浮点数运算，比 shell 的整数运算更精确
    HEAP_SIZE_IN_MB=$(echo "$CONTAINER_MEMORY_LIMIT" | awk '{printf "%d", ($1 / 1024 / 1024 * 0.75)}')
    HEAP_PARAM="-XX:MaxHeapSize=${HEAP_SIZE_IN_MB}m"
    echo "信息：[INFO] 检测到 Cgroup $CGROUP_VERSION 内存限制，自动设置JVM最大堆内存为 ${HEAP_SIZE_IN_MB}m"
fi

# 如果经过上述检测后，HEAP_PARAM 仍然为空，说明没有设置内存限制
if [ -z "$HEAP_PARAM" ]; then
    HEAP_PARAM=$DEFAULT_HEAP_PARAM
    echo "警告：[WARN] 未检测到有效的 Docker 内存限制，使用默认JVM最大堆内存：2g"
fi


# =================================================================
#                         运行阶段
# =================================================================
# 切换到数据目录 (来自您的脚本, 完全保留)
cd "$DATA_DIR"

echo "Initialization complete. Starting Java application..."

# 使用 exec 将控制权完全交给 Java 进程。
# 【修改点】将 -XX:MaxHeapSize=2g 替换为我们动态计算的 $HEAP_PARAM 变量
exec /opt/java/openjdk/bin/java \
    -XX:+UseZGC \
    -XX:ZUncommitDelay=10 \
    $HEAP_PARAM \
    -jar ../app.jar \
    --spring.config.location=file:"$CONFIG_FILE"
