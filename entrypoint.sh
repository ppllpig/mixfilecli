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
    echo "WebDAV data file not found. Creating empty GZIP file at $WEB_DAV_FILE"
    # 一个空的 GZIP 文件（20 字节）
    # 1f8b0800efd5bc6802ff03000000000000000000
    echo '<?xml version="1.0" encoding="utf-8" ?><D:multistatus xmlns:D="DAV:"></D:multistatus>' | gzip > "$WEB_DAV_FILE"
fi
# 检查并创建 history.mix_list 文件
if [ ! -f "$HISTORY_FILE" ]; then
    echo "History file not found. Creating empty GZIP file at $HISTORY_FILE"
    # 一个空的 GZIP 文件（20 字节）
    # 1f8b0800efd5bc6802ff03000000000000000000
    echo -ne '\x1f\x8b\x08\x00\xef\xd5\xbc\x68\x02\xff\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$HISTORY_FILE"
fi

# 使用 exec 来执行 Java 应用。
# 这会让 Java 进程替换掉 shell 进程，成为容器的主进程 (PID 1)，
# 从而能够正确地接收和处理来自 Docker 的停止信号 (如 SIGTERM)。

MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Attempting to start Java application (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."
    cd "$DATA_DIR"
    java -jar ../app.jar --spring.config.location=file:"$CONFIG_FILE"
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "Java application started successfully."
        exit 0
    else
        echo "Java application exited with error code $EXIT_CODE."
        # 检查错误日志中是否包含 WebDAV 存档失败或 EOFException
        if grep -q "载入WebDAV存档失败" /dev/stderr || grep -q "java.io.EOFException" /dev/stderr; then
            echo "Detected WebDAV archive loading failure or EOFException. Deleting $WEB_DAV_FILE and retrying..."
            rm -f "$WEB_DAV_FILE"
            RETRY_COUNT=$((RETRY_COUNT + 1))
            sleep 5 # 等待一段时间再重试
        else
            echo "Unknown error. Exiting."
            exit $EXIT_CODE
        fi
    fi
done

echo "Failed to start Java application after $MAX_RETRIES attempts due to WebDAV archive loading failure."
exit 1
