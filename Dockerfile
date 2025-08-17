# --- STAGE 1: 构建环境 ---
# 使用与项目匹配的 Java 8 JDK slim 镜像
FROM openjdk:8-jdk-slim as builder

WORKDIR /app

# 复制构建所需的文件
COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts .
COPY settings.gradle.kts .
COPY src src

# 赋予 gradlew 执行权限
RUN chmod +x ./gradlew

# 运行 gradle build 来构建 fat jar
# --no-daemon 确保在 CI 环境中不会有后台进程残留
RUN ./gradlew build -x test --no-daemon

# --- STAGE 2: 运行环境 ---
# 使用更小的 Java 8 JRE slim 镜像作为最终镜像
FROM openjdk:8-jre-slim

WORKDIR /app

# 从构建阶段复制最终生成的 fat jar
# 根据 build.gradle.kts 的配置，产物名称是 mixfile-cli-1.12.2.jar
# 为了通用性，我们仍然可以使用通配符
COPY --from=builder /app/build/libs/mixfile-cli-*.jar app.jar

# 容器启动时执行的命令
ENTRYPOINT ["java", "-jar", "app.jar"]