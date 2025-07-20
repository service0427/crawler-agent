#!/bin/bash

# 간단한 에이전트 설치 스크립트 (scripts 없이도 동작)
# 사용법: curl -s YOUR_SERVER_IP:8080/install-simple.sh | bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== 웹 크롤러 에이전트 간단 설치 ===${NC}"

# 설치 디렉토리
INSTALL_DIR="${HOME}/crawler-agent"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${YELLOW}1. 기본 패키지 설치...${NC}"
if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y nodejs npm chromium-browser curl
elif command -v yum &> /dev/null; then
    sudo yum install -y nodejs npm chromium curl
fi

echo -e "${YELLOW}2. 소스 다운로드...${NC}"
# 개별 파일 다운로드
curl -o package.json "http://YOUR_SERVER_IP:8080/package.json" 2>/dev/null || {
    echo "package.json 생성..."
    cat > package.json << 'EOF'
{
  "name": "crawler-agent",
  "version": "1.0.0",
  "description": "Distributed web crawler agent",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js"
  },
  "dependencies": {
    "axios": "^1.10.0",
    "dotenv": "^17.0.1",
    "express": "^5.1.0",
    "playwright": "^1.53.2"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
}

# 최소 필요 디렉토리 생성
mkdir -p src/workflows logs data/users config

echo -e "${YELLOW}3. 환경설정 파일 생성...${NC}"
cat > .env << 'EOF'
PORT=3001
AGENT_ID=agent-1
BIND_ADDRESS=0.0.0.0
HUB_URL=https://your-hub-domain.com:8443
HUB_SECRET=your-hub-secret-key-here
HEADLESS=false
DISPLAY=:0
LOG_LEVEL=info
EOF

echo -e "${YELLOW}4. 의존성 설치...${NC}"
npm install
npx playwright install chromium

echo -e "${GREEN}✓ 기본 설치 완료!${NC}"
echo
echo "추가 작업 필요:"
echo "1. src/index.js 파일을 직접 복사하거나 다운로드"
echo "2. src/workflows/ 폴더 내용 복사"
echo
echo "scp 사용 예시:"
echo "scp user@YOUR_SERVER_IP:/home/tech/crawler/agent/src/index.js src/"
echo "scp -r user@YOUR_SERVER_IP:/home/tech/crawler/agent/src/workflows/* src/workflows/"
echo
echo "또는 전체 패키지 다운로드:"
echo "curl -o agent.tar.gz http://YOUR_SERVER_IP:8080/crawler-agent.tar.gz"
echo "tar -xzf agent.tar.gz --strip-components=1"