# ==========================================
# Stage 1: Build stage với JDK 21 Alpine
# ==========================================
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Sao chép Gradle Wrapper và file cấu hình dependencies từ thư mục backend
COPY backend/gradlew backend/gradlew.bat backend/settings.gradle backend/build.gradle ./
COPY backend/gradle ./gradle

# Cấp quyền thực thi cho gradlew và tải trước dependencies
RUN chmod +x ./gradlew && ./gradlew dependencies --no-daemon || true

# Sao chép toàn bộ mã nguồn backend
COPY backend/src ./src

# Chạy kiểm thử Gradle và đóng gói ứng dụng Spring Boot
RUN ./gradlew test --no-daemon && ./gradlew bootJar --no-daemon

# ==========================================
# Stage 2: Runtime stage với JRE 21 Alpine nhẹ và an toàn
# ==========================================
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Tạo non-root user để tăng tính bảo mật
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Sao chép file jar từ builder stage
COPY --from=builder /app/build/libs/*.jar app.jar

# Phân quyền cho non-root user
USER appuser:appgroup

# Khai báo cổng ứng dụng
EXPOSE 8080

# Cấu hình biến môi trường mặc định
ENV SERVER_PORT=8080 \
    JAVA_OPTS="-Xms256m -Xmx512m"

# Healthcheck kiểm tra định kỳ trạng thái ứng dụng qua /actuator/health
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${SERVER_PORT}/actuator/health || exit 1

# Khởi chạy ứng dụng
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
