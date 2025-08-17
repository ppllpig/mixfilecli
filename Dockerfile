# --- STAGE 1: 构建环境 (Builder) ---
# 使用一个高版本的 JDK (如 17) 来确保 Gradle Wrapper 本身能够运行，无论其版本如何。
# 这提供了最佳的构建兼容性。
FROM openjdk:17-jdk-slim as builder

WORKDIR /app

# 复制构建所需的文件
COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts .
COPY settings.gradle.kts .
COPY src src

# 赋予 gradlew 执行权限
RUN chmod +x ./gradlew

# 运行 gradle build。
# Gradle 会根据 build.gradle.kts 的设置 (targetCompatibility = 1.8)
# 自动将代码编译成 Java 8 兼容的字节码。
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
