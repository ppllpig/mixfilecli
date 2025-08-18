# --- STAGE 1: 构建环境 (Builder) ---
# 使用一个高版本的 JDK (如 17) 作为基础，以确保 Gradle Wrapper 本身能够运行。
FROM openjdk:17-jdk-slim as builder

# 安装项目 toolchain 所需的 JDK 8。
# 由于 Debian 11 (Bullseye) 的默认源中没有 openjdk-8-jdk，
# 我们需要添加 Eclipse Temurin (前 AdoptOpenJDK) 的软件源来安装。
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    apt-transport-https \
    gnupg \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor > /usr/share/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bullseye main" > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-8-jdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制构建所需的文件
COPY upstream_source/gradlew .
COPY upstream_source/gradle gradle
COPY upstream_source/build.gradle.kts .
COPY upstream_source/settings.gradle.kts .
COPY upstream_source/gradle.properties .
COPY upstream_source/src src

# 赋予 gradlew 执行权限
RUN chmod +x ./gradlew

# 运行 gradle build。
# Gradle Wrapper 会使用默认的 JDK 17 启动。
# 但由于 toolchain 的配置，Gradle 会自动检测并使用我们刚刚安装的 JDK 8 来编译代码。
RUN ./gradlew build -x test --no-daemon

# --- STAGE 2: 运行环境 (Final Image) ---
# 最终的运行环境严格使用项目所需的 Java 8 JRE。
FROM openjdk:8-jre-slim

WORKDIR /app

# 从构建阶段复制最终生成的 fat jar。
# 这个 jar 包已经是 Java 8 兼容的了。
COPY --from=builder /app/build/libs/mixfile-cli-*.jar app.jar

# 从构建阶段复制默认的配置文件，以便在首次运行时可以自动生成
COPY --from=builder /app/src/main/resources/config.yml /app/config.yml.default

# 复制 entrypoint 脚本并赋予执行权限
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 将 entrypoint 脚本设置为容器的启动入口
ENTRYPOINT ["/app/entrypoint.sh"]
