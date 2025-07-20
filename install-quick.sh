#!/bin/bash

# 웹 크롤러 에이전트 빠른 설치 스크립트
# 사용법: 
# curl -sL https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh -o install.sh && bash install.sh
# 또는
# wget -qO- https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash -s -- --auto

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
DEFAULT_INSTALL_DIR="${HOME}/crawler-agent"
SOURCE_SERVER="YOUR_SERVER_IP:8080"

# 기존 설치 확인
EXISTING_INSTALL=false
UPDATE_MODE=false
BACKUP_ENV=false

# 자동 모드 확인
AUTO_MODE=false
if [ "$1" = "--auto" ]; then
    AUTO_MODE=true
fi

# 설치 디렉토리 확인 및 선택
if [ -d "$DEFAULT_INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠️  기존 디렉토리가 발견되었습니다: $DEFAULT_INSTALL_DIR${NC}"
    
    if [ "$AUTO_MODE" = true ]; then
        echo "자동 모드: 기존 설치 업데이트"
        choice="1"
    else
        echo "선택하세요:"
        echo "1) 기존 설치 업데이트"
        echo "2) 새로운 디렉토리에 설치"
        echo "3) 취소"
        
        if [ -t 0 ]; then
            read -p "선택 [1-3]: " choice
        else
            echo -e "${RED}\n파이프 실행 감지. 다음 명령을 사용하세요:${NC}"
            echo "curl -sL https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh -o install.sh && bash install.sh"
            echo "또는 --auto 옵션 사용:"
            echo "curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash -s -- --auto"
            exit 1
        fi
    fi
    
    case $choice in
        1)
            INSTALL_DIR="$DEFAULT_INSTALL_DIR"
            UPDATE_MODE=true
            EXISTING_INSTALL=true
            ;;
        2)
            if [ -t 0 ]; then
                read -p "새 설치 디렉토리 경로 (예: ${HOME}/crawler-agent-2): " NEW_DIR
            else
                echo -e "${RED}대화형 입력이 불가능합니다.${NC}"
                exit 1
            fi
            if [ -z "$NEW_DIR" ]; then
                echo -e "${RED}디렉토리를 입력하지 않았습니다. 취소합니다.${NC}"
                exit 1
            fi
            INSTALL_DIR="$NEW_DIR"
            ;;
        3)
            echo -e "${YELLOW}설치를 취소합니다.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}잘못된 선택입니다. 취소합니다.${NC}"
            exit 1
            ;;
    esac
else
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
fi

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}        기존 설치 감지됨 - 업데이트 모드로 진행${NC}" 
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    EXISTING_INSTALL=true
    UPDATE_MODE=true
    
    # 기존 .env 파일 백업
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo -e "${YELLOW}기존 .env 파일 백업 중...${NC}"
        cp "$INSTALL_DIR/.env" "$INSTALL_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
        BACKUP_ENV=true
    fi
    
    # 실행 중인 에이전트 확인
    RUNNING_AGENTS=$(pgrep -f "node.*src/index.js" | wc -l)
    if [ $RUNNING_AGENTS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  실행 중인 에이전트 $RUNNING_AGENTS개 발견${NC}"
        echo "업데이트 후 에이전트를 재시작해야 합니다."
        echo
    fi
fi

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

echo -e "${YELLOW}2. Chrome 브라우저 설치 확인 중...${NC}"

# Chrome 브라우저 확인
CHROME_INSTALLED=false
if command -v google-chrome &> /dev/null || command -v google-chrome-stable &> /dev/null; then
    CHROME_VERSION=$(google-chrome --version 2>/dev/null || google-chrome-stable --version 2>/dev/null)
    echo -e "${GREEN}✓ Google Chrome이 이미 설치되어 있습니다: $CHROME_VERSION${NC}"
    CHROME_INSTALLED=true
else
    echo -e "${YELLOW}Google Chrome이 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian - Chrome 설치
        echo "Chrome 저장소 추가 중..."
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
        sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
        sudo apt-get update
        sudo apt-get install -y google-chrome-stable
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Google Chrome 설치 완료${NC}"
            CHROME_INSTALLED=true
        else
            echo -e "${RED}Chrome 설치 실패. Chromium으로 대체합니다.${NC}"
            sudo apt-get install -y chromium-browser
        fi
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL - Chrome 설치
        cat << EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
        sudo yum install -y google-chrome-stable
    elif command -v dnf &> /dev/null; then
        # Fedora - Chrome 설치
        sudo dnf install -y fedora-workstation-repositories
        sudo dnf config-manager --set-enabled google-chrome
        sudo dnf install -y google-chrome-stable
    fi
fi

echo -e "${YELLOW}3. 기본 패키지 설치 중...${NC}"

# 시스템 업데이트 및 기본 패키지 설치
if command -v apt-get &> /dev/null; then
    # Ubuntu/Debian
    sudo apt-get update
    sudo apt-get install -y curl wget git unzip
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    sudo yum update -y
    sudo yum install -y curl wget git unzip
elif command -v dnf &> /dev/null; then
    # Fedora
    sudo dnf update -y
    sudo dnf install -y curl wget git unzip
fi

echo -e "${YELLOW}4. Node.js 버전 최종 확인 중...${NC}"

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

if [ "$UPDATE_MODE" = true ]; then
    echo -e "${YELLOW}5. 에이전트 파일 업데이트 중...${NC}"
else
    echo -e "${YELLOW}5. 에이전트 파일 다운로드 중...${NC}"
fi

# 설치 디렉토리 생성
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 업데이트 모드인 경우 임시 디렉토리 사용
if [ "$UPDATE_MODE" = true ]; then
    TEMP_DIR="${INSTALL_DIR}/temp_update_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
fi

# 에이전트 소스 다운로드
echo "소스 파일 다운로드 중..."

# GitHub에서 직접 tar.gz 다운로드
GITHUB_RELEASE_URL="https://github.com/service0427/crawler-agent/archive/refs/heads/main.tar.gz"
echo "GitHub에서 다운로드 중..."
curl -L -f -o crawler-agent.tar.gz "$GITHUB_RELEASE_URL" || {
    echo -e "${RED}소스 파일 다운로드 실패${NC}"
    echo -e "${YELLOW}네트워크 연결을 확인하고 다시 시도하세요.${NC}"
    echo "또는 수동으로 다운로드:"
    echo "wget https://github.com/service0427/crawler-agent/archive/refs/heads/main.tar.gz"
    exit 1
}

# 압축 해제
if [ -f "crawler-agent.tar.gz" ]; then
    echo "압축 해제 중..."
    # GitHub tar.gz는 디렉토리 구조가 다름 (crawler-agent-main)
    tar -xzf crawler-agent.tar.gz
    
    # 추출된 디렉토리 확인 및 파일 이동
    if [ -d "crawler-agent-main" ]; then
        # 파일들을 현재 디렉토리로 이동
        mv crawler-agent-main/* . 2>/dev/null || true
        mv crawler-agent-main/.* . 2>/dev/null || true
        rm -rf crawler-agent-main
    fi
    
    rm crawler-agent.tar.gz
    echo -e "${GREEN}✓ 압축 해제 완료${NC}"
else
    echo -e "${RED}다운로드된 파일이 없습니다.${NC}"
    exit 1
fi

# 업데이트 모드인 경우 파일 비교 및 선택적 복사
if [ "$UPDATE_MODE" = true ]; then
    echo -e "${YELLOW}변경된 파일 확인 및 업데이트 중...${NC}"
    
    # 중요 파일들 업데이트 (항상 덮어쓰기)
    CORE_FILES=(
        "src/index.js"
        "src/workflows/"
        "scripts/"
        "config/"
        "icons/"
        "package.json"
        "README.md"
        "CLAUDE.md"
        "dev-workflow.js"
    )
    
    # 파일들을 원본 디렉토리로 복사
    for file in "${CORE_FILES[@]}"; do
        if [ -e "$file" ]; then
            echo "업데이트: $file"
            if [ -d "$file" ]; then
                # 디렉토리인 경우
                rm -rf "$INSTALL_DIR/$file"
                cp -r "$file" "$INSTALL_DIR/"
            else
                # 파일인 경우
                cp "$file" "$INSTALL_DIR/"
            fi
        fi
    done
    
    # .env.example만 복사 (기존 .env는 보존)
    if [ -f ".env.example" ]; then
        cp ".env.example" "$INSTALL_DIR/"
    fi
    
    # .gitignore 업데이트
    if [ -f ".gitignore" ]; then
        cp ".gitignore" "$INSTALL_DIR/"
    fi
    
    # package.json 변경 확인
    PACKAGE_CHANGED=false
    if ! cmp -s "package.json" "$INSTALL_DIR/package.json" 2>/dev/null; then
        PACKAGE_CHANGED=true
        echo -e "${YELLOW}package.json 변경 감지됨 - 의존성 업데이트 필요${NC}"
    fi
    
    # 임시 디렉토리 정리
    cd "$INSTALL_DIR"
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✓ 파일 업데이트 완료${NC}"
else
    echo -e "${GREEN}✓ 소스 파일 다운로드 완료${NC}"
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

echo -e "${YELLOW}6. 의존성 확인 및 설치 중...${NC}"

# package.json 존재 확인
if [ ! -f "package.json" ]; then
    echo -e "${RED}package.json 파일이 없습니다.${NC}"
    exit 1
fi

# 업데이트 모드에서 package.json이 변경되지 않았다면 의존성 설치 건너뛰기
if [ "$UPDATE_MODE" = true ] && [ "$PACKAGE_CHANGED" = false ] && [ -d "node_modules" ]; then
    echo -e "${GREEN}✓ 의존성에 변경사항 없음 - 설치 건너뛰기${NC}"
else
    echo "npm 의존성 설치 중..."
    npm install
    
    # Playwright 브라우저 확인 및 설치
    if [ "$UPDATE_MODE" = true ]; then
        # 업데이트 모드에서는 Playwright 브라우저가 이미 있는지 확인
        if command -v playwright &> /dev/null && playwright browsers list | grep -q "chromium"; then
            echo -e "${GREEN}✓ Playwright 브라우저 이미 설치됨${NC}"
        else
            echo "Playwright 브라우저 설치 중..."
            npx playwright install chromium
        fi
    else
        echo "Playwright 브라우저 설치 중..."
        npx playwright install chromium
    fi
    
    echo -e "${GREEN}✓ 의존성 설치 완료${NC}"
fi

echo -e "${YELLOW}7. 환경 설정 중...${NC}"

# .env 파일 처리
if [ "$UPDATE_MODE" = true ] && [ "$BACKUP_ENV" = true ]; then
    echo -e "${GREEN}✓ 기존 .env 파일 보존됨${NC}"
    echo -e "${YELLOW}새로운 설정은 .env.example을 참고하세요${NC}"
elif [ ! -f ".env" ]; then
    echo "기본 .env 파일 생성 중..."
    
    # 에이전트 ID 설정
    HOSTNAME=$(hostname)
    DEFAULT_AGENT_ID="agent-${HOSTNAME}-$(date +%s | tail -c 5)"
    
    if [ "$AUTO_MODE" = true ]; then
        AGENT_ID="$DEFAULT_AGENT_ID"
        echo -e "${YELLOW}자동 모드: 에이전트 ID = $AGENT_ID${NC}"
    else
        echo -e "${YELLOW}에이전트 ID를 설정하세요.${NC}"
        echo "여러 위치에서 설치하는 경우 각각 다른 ID를 사용해야 합니다."
        
        if [ -t 0 ]; then
            read -p "에이전트 ID [기본값: $DEFAULT_AGENT_ID]: " AGENT_ID_INPUT
            AGENT_ID="${AGENT_ID_INPUT:-$DEFAULT_AGENT_ID}"
        else
            echo -e "${RED}대화형 입력 불가. 기본값 사용: $DEFAULT_AGENT_ID${NC}"
            AGENT_ID="$DEFAULT_AGENT_ID"
        fi
    fi
    
    echo -e "${GREEN}✓ 에이전트 ID: $AGENT_ID${NC}"
    
    # 프로덕션 환경 사용 여부 확인
    if [ "$AUTO_MODE" = true ]; then
        echo -e "${YELLOW}자동 모드: 프로덕션 허브 사용${NC}"
        HUB_CHOICE="1"
    else
        echo -e "${YELLOW}프로덕션 허브에 연결하시겠습니까?${NC}"
        echo "1) 예, 프로덕션 허브 사용 (mkt.techb.kr)"
        echo "2) 아니오, 커스텀 허브 사용"
        
        if [ -t 0 ]; then
            read -p "선택 [1-2]: " HUB_CHOICE
        else
            echo -e "${RED}대화형 입력 불가. 커스텀 허브 설정 사용${NC}"
            HUB_CHOICE="2"
        fi
    fi
    
    if [ "$HUB_CHOICE" = "1" ]; then
        # 프로덕션 허브 설정 로드
        if [ -f "./hub-config.sh" ]; then
            source ./hub-config.sh
            HUB_URL="$PROD_HUB_URL"
            ALLOWED_HUB_IPS="$PROD_HUB_IPS"
        else
            HUB_URL="https://mkt.techb.kr:8443"
            ALLOWED_HUB_IPS="mkt.techb.kr,220.78.239.115"
        fi
        
        # 허브 시크릿 입력
        if [ "$AUTO_MODE" = true ] || [ ! -t 0 ]; then
            echo -e "${YELLOW}허브 시크릿은 .env 파일에서 설정하세요.${NC}"
            HUB_SECRET="your-hub-secret-key-here"
        else
            echo -e "${YELLOW}프로덕션 허브 시크릿 키를 입력하세요:${NC}"
            read -s -p "HUB_SECRET: " HUB_SECRET_INPUT
            echo
        fi
        
        if [ -z "$HUB_SECRET_INPUT" ]; then
            echo -e "${RED}시크릿 키가 입력되지 않았습니다.${NC}"
            echo "설치 후 .env 파일에서 수정하세요."
            HUB_SECRET="your-hub-secret-key-here"
        else
            HUB_SECRET="$HUB_SECRET_INPUT"
            echo -e "${GREEN}✓ 허브 시크릿 설정 완료${NC}"
        fi
        
        echo -e "${GREEN}✓ 프로덕션 허브 설정 적용${NC}"
    else
        # 커스텀 허브 설정
        HUB_URL="https://your-hub-domain.com:8443"
        HUB_SECRET="your-hub-secret-key"
        ALLOWED_HUB_IPS="your-hub-domain.com,your-hub-ip"
        echo -e "${YELLOW}설치 후 .env 파일에서 허브 설정을 수정하세요.${NC}"
    fi
    
    # .env 파일 생성
    cat > .env << EOF
# Agent Configuration
PORT=3001
AGENT_ID=$AGENT_ID
BIND_ADDRESS=0.0.0.0

# Hub Connection
HUB_URL=$HUB_URL
HUB_SECRET=$HUB_SECRET
ALLOWED_HUB_IPS=$ALLOWED_HUB_IPS

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
    echo -e "${GREEN}✓ .env 파일 생성 완료${NC}"
else
    echo -e "${GREEN}✓ .env 파일 이미 존재함${NC}"
fi

# 필요한 디렉토리 생성
mkdir -p logs data/users

echo -e "${GREEN}✓ 환경 설정 완료${NC}"

echo -e "${YELLOW}8. 권한 설정 중...${NC}"

# 스크립트 실행 권한 부여
chmod +x scripts/*.sh

echo -e "${GREEN}✓ 권한 설정 완료${NC}"

echo
if [ "$UPDATE_MODE" = true ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        업데이트가 완료되었습니다!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [ $RUNNING_AGENTS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  실행 중인 에이전트 재시작 필요:${NC}"
        echo "1. 현재 실행 중인 에이전트 정지:"
        echo "   ./scripts/manage.sh  # 메뉴에서 4번 선택 (모든 에이전트 정지)"
        echo
        echo "2. 에이전트 재시작:"
        echo "   ./scripts/manage.sh  # 메뉴에서 3번 선택 (다중 에이전트 시작)"
        echo
    else
        echo -e "${YELLOW}다음 단계:${NC}"
        echo "1. 에이전트 실행:"
        echo "   ./scripts/manage.sh  # 메뉴에서 3번 선택"
        echo
    fi
    
    if [ "$BACKUP_ENV" = true ]; then
        echo -e "${YELLOW}참고:${NC}"
        echo "- 기존 .env 설정이 보존되었습니다"
        echo "- 새로운 설정 옵션은 .env.example을 확인하세요"
        echo "- .env 백업 파일들: .env.backup.*"
        echo
    fi
    
else
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        설치가 완료되었습니다!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    if [ "$HUB_CHOICE" = "1" ]; then
        echo -e "${GREEN}✓ 프로덕션 허브 설정 완료${NC}"
        echo -e "${YELLOW}설정된 허브 정보:${NC}"
        echo "- 허브 URL: $HUB_URL"
        echo "- 에이전트 ID: $AGENT_ID"
        echo
        echo -e "${YELLOW}다음 단계:${NC}"
        echo "1. 에이전트 실행:"
    else
        echo -e "${YELLOW}다음 단계:${NC}"
        echo "1. 허브 설정 확인:"
        echo "   nano .env  # HUB_URL과 HUB_SECRET을 실제 값으로 변경"
        echo
        echo "2. 에이전트 실행:"
    fi
    echo "   npm start"
    echo "   # 또는"
    echo "   ./scripts/manage.sh"
    echo
    echo "2. 멀티 에이전트 실행:"
    echo "   ./scripts/manage.sh"
    echo "   # 메뉴에서 3번 선택"
    echo
    echo "4. 서비스로 등록 (선택사항):"
    echo "   sudo ./scripts/systemd-setup.sh install-multi"
    echo
fi

echo -e "${BLUE}설치 경로: ${INSTALL_DIR}${NC}"
echo -e "${BLUE}로그 파일: ${INSTALL_DIR}/logs/${NC}"
echo
echo -e "${YELLOW}문제가 있으면 logs/agent.log 파일을 확인하세요.${NC}"