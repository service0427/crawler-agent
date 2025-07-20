#!/bin/bash

# 웹 크롤러 에이전트 빠른 설치 스크립트
# 사용법: curl -s 220.78.239.115:8080/install-quick.sh | bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}        Web Crawler Agent 빠른 설치 스크립트${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

# 스크립트 실행 권한 확인
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}root 권한으로 실행 중입니다.${NC}"
fi

# 설치 디렉토리 설정
INSTALL_DIR="${HOME}/crawler-agent"
SOURCE_SERVER="220.78.239.115:8080"

echo -e "${YELLOW}1. Node.js 설치 확인 중...${NC}"

# Node.js가 이미 설치되어 있는지 확인
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 2>/dev/null)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
    
    if [ $NODE_MAJOR -ge 18 ]; then
        echo -e "${GREEN}✓ Node.js v$NODE_VERSION이 이미 설치되어 있습니다.${NC}"
    else
        echo -e "${YELLOW}Node.js v$NODE_VERSION이 설치되어 있지만 버전이 낮습니다.${NC}"
        echo -e "${YELLOW}Node.js v18 이상이 필요합니다. 업데이트를 진행합니다...${NC}"
        
        # Node.js 업데이트
        if command -v apt-get &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v yum &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_current.x | sudo bash -
            sudo yum install -y nodejs npm
        elif command -v dnf &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_current.x | sudo bash -
            sudo dnf install -y nodejs npm
        fi
    fi
else
    echo -e "${YELLOW}Node.js가 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"
    
    # Node.js 설치
    if command -v apt-get &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_current.x | sudo bash -
        sudo yum install -y nodejs npm
    elif command -v dnf &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_current.x | sudo bash -
        sudo dnf install -y nodejs npm
    else
        echo -e "${RED}지원되지 않는 패키지 매니저입니다.${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}2. 기본 패키지 설치 중...${NC}"

# 시스템 업데이트 및 기본 패키지 설치 (Node.js 제외)
if command -v apt-get &> /dev/null; then
    # Ubuntu/Debian
    sudo apt-get update
    sudo apt-get install -y curl wget git unzip chromium-browser
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    sudo yum update -y
    sudo yum install -y curl wget git unzip chromium
elif command -v dnf &> /dev/null; then
    # Fedora
    sudo dnf update -y
    sudo dnf install -y curl wget git unzip chromium
fi

echo -e "${YELLOW}3. Node.js 버전 최종 확인 중...${NC}"

# Node.js 버전 최종 확인
NODE_VERSION=$(node -v | cut -d'v' -f2 2>/dev/null)
if [ -z "$NODE_VERSION" ]; then
    echo -e "${RED}Node.js 설치에 실패했습니다.${NC}"
    exit 1
fi

NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
if [ $NODE_MAJOR -lt 18 ]; then
    echo -e "${RED}Node.js 버전이 여전히 낮습니다: v$NODE_VERSION${NC}"
    echo "Node.js v18 이상이 필요합니다."
    exit 1
fi

echo -e "${GREEN}✓ Node.js v$NODE_VERSION 확인됨${NC}"

echo -e "${YELLOW}4. 에이전트 파일 다운로드 중...${NC}"

# 설치 디렉토리 생성
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 에이전트 소스 다운로드
echo "소스 파일 다운로드 중..."
curl -f -o crawler-agent.tar.gz "http://${SOURCE_SERVER}/crawler-agent.tar.gz" || {
    echo -e "${YELLOW}소스 파일 다운로드 실패, GitHub에서 다운로드 시도 중...${NC}"
    
    # GitHub에서 직접 클론
    if command -v git &> /dev/null; then
        git clone https://github.com/service0427/crawler-agent.git temp-clone
        if [ -d "temp-clone" ]; then
            mv temp-clone/* . 2>/dev/null || true
            mv temp-clone/.* . 2>/dev/null || true
            rm -rf temp-clone
            echo -e "${GREEN}✓ GitHub에서 다운로드 완료${NC}"
        else
            echo -e "${RED}GitHub 클론 실패${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Git이 설치되지 않았습니다.${NC}"
        echo "다음 방법을 사용하세요:"
        echo "1. Git 설치 후 재시도"
        echo "2. 수동으로 클론: git clone https://github.com/service0427/crawler-agent.git"
        exit 1
    fi
}

# 압축 해제 (tar.gz 파일이 있는 경우만)
if [ -f "crawler-agent.tar.gz" ]; then
    tar -xzf crawler-agent.tar.gz --strip-components=1
    rm crawler-agent.tar.gz
fi

# scripts 폴더 존재 확인
if [ ! -d "scripts" ]; then
    echo -e "${RED}scripts 폴더가 없습니다. 패키지에 문제가 있을 수 있습니다.${NC}"
    echo "수동으로 다운로드를 시도합니다..."
    
    # 개별 스크립트 다운로드 시도
    mkdir -p scripts
    curl -f -o scripts/manage.sh "http://${SOURCE_SERVER}/scripts/manage.sh" 2>/dev/null || echo "manage.sh 다운로드 실패"
    curl -f -o scripts/install.sh "http://${SOURCE_SERVER}/scripts/install.sh" 2>/dev/null || echo "install.sh 다운로드 실패"
    curl -f -o scripts/systemd-setup.sh "http://${SOURCE_SERVER}/scripts/systemd-setup.sh" 2>/dev/null || echo "systemd-setup.sh 다운로드 실패"
    
    if [ ! -f "scripts/manage.sh" ]; then
        echo -e "${YELLOW}scripts가 없어도 npm start로 기본 실행은 가능합니다.${NC}"
    fi
fi

echo -e "${GREEN}✓ 소스 파일 다운로드 완료${NC}"

echo -e "${YELLOW}5. 의존성 설치 중...${NC}"

# npm 의존성 설치
npm install

# Playwright 브라우저 설치
npx playwright install chromium

echo -e "${GREEN}✓ 의존성 설치 완료${NC}"

echo -e "${YELLOW}6. 환경 설정 중...${NC}"

# .env 파일 생성
cat > .env << EOF
# Agent Configuration
PORT=3001
AGENT_ID=agent-1
BIND_ADDRESS=0.0.0.0

# Hub Connection
HUB_URL=https://mkt.techb.kr:8443
HUB_SECRET=your-hub-secret-key

# Browser Settings
HEADLESS=false
DISPLAY=:0

# Logging
LOG_LEVEL=info
LOG_MAX_SIZE=10m
LOG_MAX_FILES=5

# Performance
MAX_CONCURRENT_WORKFLOWS=2
HEARTBEAT_INTERVAL=10000

# Data Storage
USER_DATA_DIR=./data/users
LOG_DIR=./logs
EOF

# 필요한 디렉토리 생성
mkdir -p logs data/users

echo -e "${GREEN}✓ 환경 설정 완료${NC}"

echo -e "${YELLOW}7. 권한 설정 중...${NC}"

# 스크립트 실행 권한 부여
chmod +x scripts/*.sh

echo -e "${GREEN}✓ 권한 설정 완료${NC}"

echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}        설치가 완료되었습니다!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}다음 단계:${NC}"
echo "1. 환경 설정 확인:"
echo "   nano .env"
echo
echo "2. 에이전트 실행:"
echo "   npm start"
echo "   # 또는"
echo "   ./scripts/manage.sh"
echo
echo "3. 멀티 에이전트 실행:"
echo "   ./scripts/manage.sh"
echo "   # 메뉴에서 3번 선택"
echo
echo "4. 서비스로 등록 (선택사항):"
echo "   sudo ./scripts/systemd-setup.sh install-multi"
echo
echo -e "${BLUE}설치 경로: ${INSTALL_DIR}${NC}"
echo -e "${BLUE}로그 파일: ${INSTALL_DIR}/logs/${NC}"
echo
echo -e "${YELLOW}문제가 있으면 logs/agent.log 파일을 확인하세요.${NC}"