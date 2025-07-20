#!/bin/bash

# Chrome 설치 및 설정 스크립트

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Google Chrome 설치 스크립트 ===${NC}"

# Chrome 설치 확인
check_chrome() {
    if command -v google-chrome &> /dev/null; then
        echo -e "${GREEN}✓ Google Chrome이 이미 설치되어 있습니다.${NC}"
        google-chrome --version
        return 0
    elif command -v google-chrome-stable &> /dev/null; then
        echo -e "${GREEN}✓ Google Chrome이 이미 설치되어 있습니다.${NC}"
        google-chrome-stable --version
        return 0
    else
        return 1
    fi
}

# Ubuntu/Debian에 Chrome 설치
install_chrome_debian() {
    echo -e "${YELLOW}Ubuntu/Debian에 Chrome 설치 중...${NC}"
    
    # 키 추가
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    
    # 저장소 추가
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    
    # 업데이트 및 설치
    sudo apt-get update
    sudo apt-get install -y google-chrome-stable
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chrome 설치 완료${NC}"
        return 0
    else
        echo -e "${RED}Chrome 설치 실패${NC}"
        return 1
    fi
}

# CentOS/RHEL에 Chrome 설치
install_chrome_rhel() {
    echo -e "${YELLOW}CentOS/RHEL에 Chrome 설치 중...${NC}"
    
    # 저장소 설정
    cat << EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    
    # 설치
    sudo yum install -y google-chrome-stable
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chrome 설치 완료${NC}"
        return 0
    else
        echo -e "${RED}Chrome 설치 실패${NC}"
        return 1
    fi
}

# Fedora에 Chrome 설치
install_chrome_fedora() {
    echo -e "${YELLOW}Fedora에 Chrome 설치 중...${NC}"
    
    # 저장소 활성화
    sudo dnf install -y fedora-workstation-repositories
    sudo dnf config-manager --set-enabled google-chrome
    
    # 설치
    sudo dnf install -y google-chrome-stable
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chrome 설치 완료${NC}"
        return 0
    else
        echo -e "${RED}Chrome 설치 실패${NC}"
        return 1
    fi
}

# 메인 로직
if check_chrome; then
    exit 0
fi

echo -e "${YELLOW}Chrome이 설치되어 있지 않습니다. 설치를 시작합니다...${NC}"

# OS 감지 및 설치
if [ -f /etc/debian_version ]; then
    install_chrome_debian
elif [ -f /etc/redhat-release ]; then
    if command -v dnf &> /dev/null; then
        install_chrome_fedora
    else
        install_chrome_rhel
    fi
else
    echo -e "${RED}지원되지 않는 운영체제입니다.${NC}"
    echo "수동으로 Chrome을 설치해주세요: https://www.google.com/chrome/"
    exit 1
fi

# 최종 확인
if check_chrome; then
    echo -e "${GREEN}Chrome 설치가 완료되었습니다!${NC}"
    
    # Playwright용 Chrome 경로 설정 정보
    echo -e "${YELLOW}Playwright에서 Chrome을 사용하려면:${NC}"
    echo "환경변수: CHROME_PATH=/usr/bin/google-chrome-stable"
    echo "또는 코드에서: executablePath: '/usr/bin/google-chrome-stable'"
else
    echo -e "${RED}Chrome 설치에 실패했습니다.${NC}"
    exit 1
fi