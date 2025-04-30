#!/bin/bash

TARGET=$1
NGINX_CONF_PATH=proxy/nginx.conf

# 색상 코드
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# Health Check: docker network 상의 서비스명 기준
function health_check() {
  local service=$1
  local port

  if [ "$service" == "blue" ]; then
    port=8081
  else
    port=8082
  fi

  echo "🔎 Health Check: $service (localhost:$port)"

  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:$port/)
  if [ "$http_code" == "200" ]; then
    echo -e "${GREEN}✅ $service 응답 확인 성공 (HTTP 200)${NC}"
    return 0
  else
    echo -e "${RED}❌ $service 응답 실패 (code: $http_code)${NC}"
    return 1
  fi
}

# 트래픽 상태 확인
if [ "$TARGET" == "status" ]; then
  CURRENT=$(awk '/upstream app_servers/,/}/ { if ($1 == "server") print $2 }' "$NGINX_CONF_PATH" | cut -d: -f1 | tr -d ';')
  echo -e "🔍 현재 트래픽 대상: ${BLUE}${CURRENT}${NC}"
  exit 0
fi

# 입력값 검사
if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
  echo "Usage: $0 {blue|green|status}"
  exit 1
fi

# Health Check 먼저
if ! health_check "$TARGET"; then
  echo -e "${RED}🛑 전환 중단: $TARGET 서비스가 정상적으로 응답하지 않습니다.${NC}"
  exit 1
fi

echo "🔄 Switching traffic to $TARGET..."

# nginx.conf 재생성
cat <<EOCONF > "$NGINX_CONF_PATH"
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

# proxy 컨테이너 재시작
docker compose restart proxy

echo -e "✅ 트래픽이 ${BLUE}$TARGET${NC} 으로 전환되었습니다."

