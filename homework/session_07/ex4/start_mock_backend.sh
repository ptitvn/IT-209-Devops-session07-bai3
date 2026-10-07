#!/bin/bash
# ==============================================================================
# Script: start_mock_backend.sh
# Dùng để giả lập ứng dụng Spring Boot chạy tại port 8082 phục vụ kiểm thử
# (Chạy script này nếu chưa khởi động ứng dụng Spring Boot thật)
# ==============================================================================

echo "Khởi động Mock Spring Boot Server tại http://127.0.0.1:8082 ..."

python3 - << 'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = {
            "status": "UP",
            "message": "Spring Boot Backend is healthy",
            "service": "spring-boot-api",
            "port": 8082,
            "path": self.path
        }
        self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

    def log_message(self, format, *args):
        print(f"[Mock Backend 8082] {self.address_string()} - {format % args}")

server = HTTPServer(('127.0.0.1', 8082), HealthHandler)
print("Mock Spring Boot Backend running on http://127.0.0.1:8082/ (Ctrl+C to stop)")
server.serve_forever()
EOF
