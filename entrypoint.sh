#!/bin/sh
# 使用 set -e 命令，确保脚本在任何命令执行失败时立即退出
set -e

# 定义配置文件和默认配置文件的路径
CONFIG_FILE="/app/data/config.yml"
DEFAULT_CONFIG="/app/config.yml.default"

# 检查数据卷中是否已存在配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating default configuration at $CONFIG_FILE"
    # 如果不存在，就从镜像中复制默认配置过去
    cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
fi

# 使用 exec 来执行 Java 应用。
# 这会让 Java 进程替换掉 shell 进程，成为容器的主进程 (PID 1)，
# 从而能够正确地接收和处理来自 Docker 的停止信号 (如 SIGTERM)。
exec java -jar app.jar --spring.config.location=file:"$CONFIG_FILE"