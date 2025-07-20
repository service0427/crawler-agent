#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}        Web Crawler Agent Installation Script (Linux)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

# Node.js 버전 확인
check_node() {
    echo -e "${YELLOW}Checking Node.js installation...${NC}"
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Node.js is not installed!${NC}"
        echo "Please install Node.js (v18 or higher) from https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
    
    if [ $NODE_MAJOR -lt 18 ]; then
        echo -e "${RED}Node.js version is too old: v$NODE_VERSION${NC}"
        echo "Please upgrade to Node.js v18 or higher"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Node.js v$NODE_VERSION${NC}"
}

# Chrome/Chromium 확인
check_browser() {
    echo -e "${YELLOW}Checking browser installation...${NC}"
    if command -v google-chrome &> /dev/null; then
        echo -e "${GREEN}✓ Google Chrome found${NC}"
    elif command -v chromium-browser &> /dev/null; then
        echo -e "${GREEN}✓ Chromium found${NC}"
    else
        echo -e "${YELLOW}Chrome/Chromium not found. Installing Chromium...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y chromium-browser
        elif command -v yum &> /dev/null; then
            sudo yum install -y chromium
        else
            echo -e "${RED}Cannot install Chromium automatically. Please install manually.${NC}"
            exit 1
        fi
    fi
}

# 디렉토리 생성
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    mkdir -p logs data/users config
    echo -e "${GREEN}✓ Directories created${NC}"
}

# 환경 설정 파일 생성
setup_env() {
    echo -e "${YELLOW}Setting up environment...${NC}"
    if [ ! -f .env ]; then
        cp .env.example .env
        echo -e "${YELLOW}Please edit .env file with your configuration${NC}"
    else
        echo -e "${GREEN}✓ .env file already exists${NC}"
    fi
}

# 의존성 설치
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${RED}Failed to install dependencies${NC}"
        exit 1
    fi
}

# Playwright 브라우저 설치
install_playwright_browsers() {
    echo -e "${YELLOW}Installing Playwright browsers...${NC}"
    npx playwright install chromium
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Playwright browsers installed${NC}"
    else
        echo -e "${RED}Failed to install Playwright browsers${NC}"
        exit 1
    fi
}

# systemd 서비스 설정 제안
suggest_systemd() {
    echo
    echo -e "${YELLOW}To run agent as a system service:${NC}"
    echo "1. Copy the systemd service file:"
    echo "   sudo cp config/crawler-agent.service /etc/systemd/system/"
    echo "2. Edit the service file with your paths"
    echo "3. Enable and start the service:"
    echo "   sudo systemctl enable crawler-agent"
    echo "   sudo systemctl start crawler-agent"
}

# 메인 설치 프로세스
main() {
    check_node
    check_browser
    create_directories
    setup_env
    install_dependencies
    install_playwright_browsers
    
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        Installation completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit .env file with your hub configuration"
    echo "2. Run single agent: npm start"
    echo "3. Run multiple agents: ./scripts/start-multi-agents.sh"
    echo
    suggest_systemd
}

# 실행
main