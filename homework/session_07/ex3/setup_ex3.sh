#!/bin/bash
set -e

echo "=========================================================="
echo "   BÀI 3: THIẾT LẬP CSDL VÀ DỊCH VỤ SYSTEMD SPRING BOOT   "
echo "=========================================================="

echo "[1/5] Khởi tạo Database và User trong MySQL..."
sudo mysql << 'EOF'
CREATE DATABASE IF NOT EXISTS springboot_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'spring-admin'@'localhost' IDENTIFIED BY 'SpringSecure@123';
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'localhost';
FLUSH PRIVILEGES;
EOF
echo "--> Đã tạo Database 'springboot_db' và User 'spring-admin' thành công."

echo "[2/5] Tạo User hệ thống 'spring-runner' (non-root, nologin)..."
if ! id "spring-runner" &>/dev/null; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin spring-runner
    echo "--> Đã tạo user spring-runner."
else
    echo "--> User spring-runner đã tồn tại."
fi

echo "[3/5] Chuẩn bị thư mục /opt/spring-app..."
sudo mkdir -p /opt/spring-app

# Nếu có file app.jar ở thư mục hiện tại thì copy vào /opt/spring-app
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/app.jar" ]; then
    sudo cp "$SCRIPT_DIR/app.jar" /opt/spring-app/app.jar
    echo "--> Đã copy app.jar từ $SCRIPT_DIR vào /opt/spring-app/app.jar"
elif [ -f "./app.jar" ]; then
    sudo cp ./app.jar /opt/spring-app/app.jar
    echo "--> Đã copy app.jar vào /opt/spring-app/app.jar"
fi

if [ -f "/opt/spring-app/app.jar" ]; then
    sudo chown -R spring-runner:spring-runner /opt/spring-app
    sudo chmod 500 /opt/spring-app/app.jar
    echo "--> Đã phân quyền /opt/spring-app/app.jar (500) cho spring-runner."
else
    echo "--> CẢNH BÁO: Chưa tìm thấy file /opt/spring-app/app.jar. Hãy chắc chắn bạn đã đặt app.jar vào /opt/spring-app/."
    sudo chown -R spring-runner:spring-runner /opt/spring-app
fi

echo "[4/5] Cấu hình file dịch vụ Systemd..."
sudo cp "$SCRIPT_DIR/spring-app.service" /etc/systemd/system/spring-app.service 2>/dev/null || sudo cp ./spring-app.service /etc/systemd/system/spring-app.service
sudo chmod 644 /etc/systemd/system/spring-app.service

echo "--> Reload daemon và khởi động dịch vụ..."
sudo systemctl daemon-reload
sudo systemctl enable --now spring-app.service

echo "[5/5] Chờ ứng dụng khởi động và in kết quả kiểm tra..."
sleep 5

echo "----------------------------------------------------------"
echo "1. Trạng thái dịch vụ (systemctl status spring-app):"
sudo systemctl status spring-app.service --no-pager || true

echo "----------------------------------------------------------"
echo "2. Cổng lắng nghe 8082 (ss -tlnp):"
ss -tlnp | grep 8082 || echo "Chưa thấy cổng 8082 (có thể ứng dụng đang nạp, hãy thử lại lệnh sau vài giây)"

echo "----------------------------------------------------------"
echo "3. Kiểm tra tiến trình Java & User chạy:"
ps -o user,pid,cmd -C java || true

echo "=========================================================="
echo "Hoàn thành! Bạn hãy copy toàn bộ phần kết quả trên gửi lại để cập nhật README.md"
