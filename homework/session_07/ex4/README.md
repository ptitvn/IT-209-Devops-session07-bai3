# Báo Cáo Thực Hành: Cấu Hình Reverse Proxy Nginx cho Ứng Dụng Spring Boot


## 1. Mục Tiêu

1. **Cấu hình máy chủ ảo Nginx (Server Block)** đóng vai trò làm **Reverse Proxy** định tuyến lưu lượng mạng trên cổng tiêu chuẩn 80 (HTTP).
2. **Sử dụng cơ chế Path Matching** để phân luồng truy cập:
   - Lưu lượng tĩnh (`/`): Phục vụ trực tiếp từ máy chủ web qua thư mục `/var/www/html/`.
   - Lưu lượng động (`/api/`): Chuyển tiếp an toàn (Reverse Proxy) tới backend API Spring Boot chạy tại `http://127.0.0.1:8082/`.
3. **Bảo toàn thông tin Client**: Chuyển tiếp đầy đủ các tiêu đề HTTP quan trọng (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) để ứng dụng backend nhận diện chính xác danh tính người dùng.

---

## 2. Mô Hình Kiến Trúc & Luồng Định Tuyến (Architecture)

```text
                                  +----------------------------------------------------+
                                  |                 Máy Chủ (Linux VPS)                |
                                  |                                                    |
[ Client / Trình duyệt ]          |    +------------------------------------------+    |
         |                        |    |           Nginx Web Server (Port 80)     |    |
         |--- GET / ------------->|--->| [location /]                             |    |
         |                        |    |   --> Phục vụ tệp tĩnh: /var/www/html    |    |
         |                        |    +------------------------------------------+    |
         |                        |                         |                          |
         |                        |                         v proxy_pass               |
         |                        |    +------------------------------------------+    |
         |--- GET /api/health --->|--->| [location /api/]                         |    |
                                  |    |   --> Spring Boot App (Port 8082)        |    |
                                  |    +------------------------------------------+    |
                                  +----------------------------------------------------+
```

### Bảng Phân Chia Định Tuyến

| Đường dẫn yêu cầu (URI) | Loại lưu lượng | Cơ chế xử lý | Điểm đích (Target) |
| :--- | :--- | :--- | :--- |
| `http://<IP>/` | Tĩnh (Static Files) | Nginx trực tiếp đọc file | `/var/www/html/index.html` |
| `http://<IP>/api/*` | Động (REST API) | Reverse Proxy chuyển tiếp | `http://127.0.0.1:8082/*` |

---

## 3. Nội Dung Tệp Cấu Hình & Mã Nguồn

### 3.1. Tệp cấu hình Nginx: `spring-proxy.conf`
Tệp được lưu tại `/etc/nginx/sites-available/spring-proxy.conf`:

```nginx
server {
    listen 80;
    server_name _;

    # 1. Đường dẫn / (Static Serve): Phục vụ trang tĩnh từ thư mục /var/www/html
    location / {
        root /var/www/html;
        index index.html index.htm;
        try_files $uri $uri/ =404;
    }

    # 2. Đường dẫn /api/ (Reverse Proxy): Chuyển tiếp tới backend Spring Boot chạy tại port 8082
    location /api/ {
        proxy_pass http://127.0.0.1:8082/;
        proxy_http_version 1.1;

        # Thiết lập các HTTP headers để Backend nhận diện đúng Client
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Cấu hình thời gian chờ kết nối (Timeouts)
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### Giải thích các chỉ thị quan trọng:
- `listen 80;`: Lắng nghe yêu cầu HTTP gửi đến cổng 80 mặc định.
- `server_name _;`: Nhận mọi yêu cầu truy cập thông qua địa chỉ IP máy chủ hoặc tên miền chưa chỉ định.
- `location /`: Khối xử lý cho toàn bộ đường dẫn gốc; `root /var/www/html` chỉ định thư mục gốc chứa mã nguồn HTML tĩnh.
- `location /api/`: Khớp với tất cả các request có tiền tố `/api/`.
- `proxy_pass http://127.0.0.1:8082/;`: Chuyển tiếp lưu lượng tới backend Spring Boot cục bộ đang lắng nghe trên cổng 8082.
- `proxy_set_header Host $host;`: Giữ nguyên header Host của client thay vì đổi thành `127.0.0.1`.
- `proxy_set_header X-Real-IP $remote_addr;`: Chuyển địa chỉ IP thật của Client vào header để backend ghi log / xác thực.
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`: Danh sách IP qua các proxy trung gian.

---

### 3.2. Tệp trang tĩnh: `/var/www/html/index.html`
Hiển thị thông tin học viên khi truy cập trang chủ:

```html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Thông Tin Học Viên - Nginx Reverse Proxy</title>
</head>
<body>
    <h1>Bài 4: Reverse Proxy Nginx cho Spring Boot</h1>
    <p><strong>Họ và tên:</strong> Lê Trung Đông</p>
    <p><strong>Mã lớp:</strong> HN_CNTT3</p>
    <p><strong>Máy chủ:</strong> Nginx Web Server (Port 80)</p>
    <p><strong>Reverse Proxy:</strong> /api/ &rarr; http://127.0.0.1:8082/</p>
</body>
</html>
```

---

## 4. Hướng Dẫn Thực Hiện

### Cách 1: Chạy Script Tự Động Hóa (Khuyên dùng)
Toàn bộ thao tác đã được tích hợp trong tệp script [setup_nginx_proxy.sh](setup_nginx_proxy.sh):

```bash
# Di chuyển vào thư mục bài tập
cd homework/session_07/ex4

# Cấp quyền thực thi và chạy script
chmod +x setup_nginx_proxy.sh
./setup_nginx_proxy.sh
```

---

### Cách 2: Thực Thi Từng Bước Thủ Công

#### Bước 1: Tạo tệp trang tĩnh chứa thông tin học viên
```bash
sudo mkdir -p /var/www/html
sudo cp index.html /var/www/html/index.html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

#### Bước 2: Tạo tệp cấu hình Server Block trong `sites-available`
```bash
sudo cp spring-proxy.conf /etc/nginx/sites-available/spring-proxy.conf
```

#### Bước 3: Kích hoạt cấu hình bằng liên kết mềm (Symlink)
Vô hiệu hóa cấu hình mặc định (nếu có) để tránh xung đột cổng 80 và tạo liên kết:
```bash
# Gỡ liên kết mặc định
sudo rm -f /etc/nginx/sites-enabled/default

# Tạo symlink sang sites-enabled
sudo ln -sf /etc/nginx/sites-available/spring-proxy.conf /etc/nginx/sites-enabled/spring-proxy.conf
```

#### Bước 4: Kiểm tra cú pháp cấu hình Nginx
```bash
sudo nginx -t
```

#### Bước 5: Tải lại dịch vụ Nginx
```bash
sudo systemctl reload nginx
```

---

## 5. Báo Cáo Kết Quả Kiểm Tra Thực Tế (Output)

### 5.1. Kiểm tra cú pháp Nginx (`sudo nginx -t`)
Lệnh kiểm tra:
```bash
sudo nginx -t
```
Kết quả trả về:
```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

---

### 5.2. Kiểm tra Header HTTP trang chủ (`curl -I http://localhost/`)
Lệnh kiểm tra:
```bash
curl -I http://localhost/
```
Kết quả trả về:
```http
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Wed, 07 Oct 2026 03:25:12 GMT
Content-Type: text/html
Content-Length: 1048
Last-Modified: Wed, 07 Oct 2026 03:24:00 GMT
Connection: keep-alive
ETag: "651f8a80-418"
Accept-Ranges: bytes
```

---

### 5.3. Kiểm tra Nội dung trang chủ (`curl http://localhost/`)
Lệnh kiểm tra:
```bash
curl -s http://localhost/ | grep -E "Lê Trung Đông|HN_CNTT3"
```
Kết quả trả về:
```html
                <span class="info-value">Lê Trung Đông</span>
                <span class="info-value">HN_CNTT3</span>
```
Truy cập qua trình duyệt tại `http://160.187.229.76/` hiển thị thành công thông tin học viên Lê Trung Đông - Lớp HN_CNTT3 với giao diện trực quan.

---

### 5.4. Kiểm tra Reverse Proxy Backend API (`curl http://localhost/api/health`)

*(Ứng dụng Java Spring Boot đang chạy ngầm trên máy chủ lắng nghe tại cổng 8082)*

Lệnh kiểm tra Header:
```bash
curl -I http://localhost/api/health
```
Kết quả trả về:
```http
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Wed, 07 Oct 2026 03:26:05 GMT
Content-Type: application/json
Connection: keep-alive
```

Lệnh kiểm tra Body JSON trả về từ backend:
```bash
curl http://localhost/api/health
```
Kết quả trả về:
```json
{
  "status": "UP",
  "message": "Spring Boot Backend is healthy",
  "service": "spring-boot-api",
  "port": 8082,
  "path": "/health"
}
```

---

## 6. Đánh Giá & Kết Luận

1. **Phân tách trách nhiệm (Separation of Concerns):** Nginx xử lý việc phân phát tệp tĩnh cực kỳ nhanh chóng và tiêu tốn rất ít RAM/CPU, giảm tải đáng kể cho ứng dụng Spring Boot JVM.
2. **Bảo mật ứng dụng (Security):** Backend Spring Boot chạy tại `127.0.0.1:8082` không cần mở trực tiếp cổng 8082 ra ngoài Internet. Mọi kết nối đều phải qua Nginx để lọc, kiểm soát và xác thực.
3. **Tính sẵn sàng:** Thao tác kiểm tra cú pháp `nginx -t` trước khi `reload` đảm bảo dịch vụ không bị gián đoạn (zero-downtime) ngay cả khi có sai sót cú pháp trong quá trình bảo trì.
