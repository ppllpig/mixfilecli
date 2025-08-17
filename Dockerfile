# --- STAGE 1: 构建环境 (Builder) ---
# 使用一个高版本的 JDK (如 17) 作为基础，以确保 Gradle Wrapper 本身能够运行。
FROM openjdk:17-jdk-slim as builder

# 安装项目 toolchain 所需的 JDK 8。
# apt-get update && apt-get install -y openjdk-8-jdk
# 这样构建环境中就同时存在了 JDK 17 (默认) 和 JDK 8。
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-8-jdk

WORKDIR /app

# 复制构建所需的文件
COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts .
COPY settings.gradle.kts .
COPY gradle.properties .
COPY src src

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

# 容器启动时执行的命令
ENTRYPOINT ["java", "-jar", "app.jar"]
