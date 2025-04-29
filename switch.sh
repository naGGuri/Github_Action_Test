#!/bin/bash

TARGET=$1

if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
  echo "Usage: $0 {blue|green}"
  exit 1
fi

echo "🔄 Switching traffic to $TARGET... (zero-downtime with volume mount)"

# 1. proxy/nginx.conf 파일 직접 수정
cat <<EOCONF > proxy/nginx.conf
events {}

http {
    upstream app_servers {
        server $TARGET:80;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://app_servers;
        }
    }
}
EOCONF

docker exec proxy nginx -s reload # soft reload

echo "✅ Traffic now going to $TARGET (with updated nginx.conf)"
