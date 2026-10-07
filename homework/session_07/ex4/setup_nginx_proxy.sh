#!/bin/bash
# ==============================================================================
# Script: setup_nginx_proxy.sh
# Bài 4: Cấu hình Reverse Proxy Nginx cho ứng dụng Spring Boot
# Tác giả: Lê Trung Đông - Lớp: HN_CNTT3
# ==============================================================================

set -e

# Xác định thư mục hiện tại của script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo " [1/6] Kiểm tra và cài đặt Nginx (nếu chưa có)"
echo "=========================================================="
if ! command -v nginx &> /dev/null; then
    echo "Nginx chưa được cài đặt. Đang tiến hành cài đặt Nginx..."
    sudo apt-get update -y
    sudo apt-get install -y nginx curl
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo "Cài đặt Nginx thành công!"
else
    echo "Nginx đã được cài đặt."
fi

echo ""
echo "=========================================================="
echo " [2/6] Triển khai trang tĩnh tại /var/www/html/index.html"
echo "=========================================================="
sudo mkdir -p /var/www/html
if [ -f "$SCRIPT_DIR/index.html" ]; then
    sudo cp "$SCRIPT_DIR/index.html" /var/www/html/index.html
else
    sudo bash -c 'cat > /var/www/html/index.html << "EOF"
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>Thông Tin Học Viên</title>
</head>
<body>
    <h1>Bài 4: Reverse Proxy Nginx</h1>
    <p>Họ tên: Lê Trung Đông</p>
    <p>Mã lớp: HN_CNTT3</p>
</body>
</html>
EOF'
fi
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
echo "Đã triển khai /var/www/html/index.html thành công."

echo ""
echo "=========================================================="
echo " [3/6] Cấu hình máy chủ ảo Nginx: spring-proxy.conf"
echo "=========================================================="
# Sao chép tệp cấu hình vào /etc/nginx/sites-available/
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
if [ -f "$SCRIPT_DIR/spring-proxy.conf" ]; then
    sudo cp "$SCRIPT_DIR/spring-proxy.conf" /etc/nginx/sites-available/spring-proxy.conf
else
    sudo bash -c 'cat > /etc/nginx/sites-available/spring-proxy.conf << "EOF"
server {
    listen 80;
    server_name _;

    # 1. Đường dẫn / (Static Serve): Phục vụ trang tĩnh từ /var/www/html
    location / {
        root /var/www/html;
        index index.html index.htm;
        try_files $uri $uri/ =404;
    }

    # 2. Đường dẫn /api/ (Reverse Proxy): Chuyển tiếp tới backend Spring Boot (port 8082)
    location /api/ {
        proxy_pass http://127.0.0.1:8082/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF'
fi

# Vô hiệu hóa site mặc định (nếu có) để tránh xung đột port 80
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "Đang vô hiệu hóa cấu hình site mặc định (/etc/nginx/sites-enabled/default)..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Kích hoạt cấu hình spring-proxy.conf bằng symlink
echo "Tạo symlink sang /etc/nginx/sites-enabled/..."
sudo ln -sf /etc/nginx/sites-available/spring-proxy.conf /etc/nginx/sites-enabled/spring-proxy.conf

echo ""
echo "=========================================================="
echo " [4/6] Kiểm tra cú pháp cấu hình Nginx"
echo "=========================================================="
sudo nginx -t

echo ""
echo "=========================================================="
echo " [5/6] Tải lại dịch vụ Nginx (Reload)"
echo "=========================================================="
sudo systemctl reload nginx || sudo systemctl restart nginx
echo "Nginx đã được nạp lại cấu hình mới thành công."

echo ""
echo "=========================================================="
echo " [6/6] Kiểm tra truy vấn HTTP (Verification)"
echo "=========================================================="
echo "--- 1. Kiểm tra Header trang tĩnh (curl -I http://localhost/) ---"
curl -I http://localhost/ || true

echo ""
echo "--- 2. Kiểm tra Nội dung trang tĩnh (curl -s http://localhost/ | grep -i 'Lê Trung Đông') ---"
curl -s http://localhost/ | grep -E "Lê Trung Đông|HN_CNTT3" || true

echo ""
echo "--- 3. Kiểm tra Reverse Proxy tới Backend (curl -I http://localhost/api/health) ---"
# Kiểm tra xem port 8082 có đang lắng nghe không
if ss -tuln | grep -q ":8082 "; then
    echo "Phát hiện dịch vụ đang lắng nghe tại port 8082:"
    curl -I http://localhost/api/health || true
else
    echo "LƯU Ý: Hiện chưa có ứng dụng chạy tại port 8082."
    echo "Nginx sẽ trả về 502 Bad Gateway khi port 8082 chưa mở."
    echo "Khi bạn khởi chạy ứng dụng Spring Boot (cổng 8082), request /api/ sẽ tự động chuyển tiếp thành công!"
fi

echo ""
echo "=========================================================="
echo " Cấu hình Nginx Reverse Proxy hoàn tất 100%!"
echo "=========================================================="
