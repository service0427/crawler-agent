#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}     웹 크롤러 에이전트 자동 시작 설정 도구${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

show_usage() {
    echo "사용법: $0 [명령] [옵션]"
    echo
    echo "명령:"
    echo "  install        Systemd 서비스 설치 (root 권한 필요)"
    echo "  enable         부팅 시 자동 시작 활성화"
    echo "  disable        부팅 시 자동 시작 비활성화"
    echo "  status         서비스 상태 확인"
    echo "  manual         수동 설치 가이드 표시"
    echo
    echo "예시:"
    echo "  sudo $0 install     # 서비스 설치"
    echo "  sudo $0 enable      # 자동 시작 활성화"
    echo "  $0 status           # 상태 확인"
    echo "  $0 manual           # 수동 설치 방법"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}이 명령은 root 권한이 필요합니다. sudo를 사용하세요.${NC}"
        echo "예: sudo $0 $1"
        exit 1
    fi
}

install_services() {
    check_root
    echo -e "${YELLOW}다중 에이전트 systemd 서비스 설치 중...${NC}"
    
    # 서비스 파일 경로 업데이트
    sed "s|/home/tech/crawler/agent|$PROJECT_ROOT|g" "$PROJECT_ROOT/config/crawler-agent@.service" > /tmp/crawler-agent@.service
    
    # systemd 디렉토리에 복사
    cp /tmp/crawler-agent@.service /etc/systemd/system/
    
    # systemd 리로드
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ 서비스가 성공적으로 설치되었습니다${NC}"
    echo
    echo "다음 명령으로 자동 시작을 활성화하세요:"
    echo "  sudo $0 enable"
}

enable_auto_start() {
    check_root
    echo -e "${YELLOW}부팅 시 자동 시작 활성화 중...${NC}"
    
    for port in 3001 3002 3003 3004; do
        echo -n "포트 $port 에이전트 자동 시작 활성화... "
        systemctl enable crawler-agent@$port
        echo -e "${GREEN}✓${NC}"
    done
    
    echo -e "${GREEN}✓ 모든 에이전트의 자동 시작이 활성화되었습니다${NC}"
    echo
    echo "에이전트를 지금 시작하려면:"
    echo "  sudo systemctl start crawler-agent@3001"
    echo "  sudo systemctl start crawler-agent@3002"
    echo "  sudo systemctl start crawler-agent@3003"
    echo "  sudo systemctl start crawler-agent@3004"
    echo
    echo "또는 관리 도구 사용:"
    echo "  ./scripts/manage.sh"
}

disable_auto_start() {
    check_root
    echo -e "${YELLOW}부팅 시 자동 시작 비활성화 중...${NC}"
    
    for port in 3001 3002 3003 3004; do
        echo -n "포트 $port 에이전트 자동 시작 비활성화... "
        systemctl disable crawler-agent@$port
        echo -e "${GREEN}✓${NC}"
    done
    
    echo -e "${GREEN}✓ 모든 에이전트의 자동 시작이 비활성화되었습니다${NC}"
}

show_status() {
    echo -e "${YELLOW}Systemd 서비스 상태:${NC}"
    echo "────────────────────────────────────────"
    
    # 서비스 파일 설치 확인
    if [ -f "/etc/systemd/system/crawler-agent@.service" ]; then
        echo -e "${GREEN}✓ Systemd 서비스 설치됨${NC}"
    else
        echo -e "${RED}✗ Systemd 서비스 설치 안됨${NC}"
        echo "  설치하려면: sudo $0 install"
        return
    fi
    
    echo
    echo "에이전트별 상태:"
    for port in 3001 3002 3003 3004; do
        echo -n "포트 $port: "
        
        # 활성화 상태 확인
        if systemctl is-enabled crawler-agent@$port >/dev/null 2>&1; then
            enabled_status="${GREEN}자동시작 활성화${NC}"
        else
            enabled_status="${RED}자동시작 비활성화${NC}"
        fi
        
        # 실행 상태 확인
        if systemctl is-active crawler-agent@$port >/dev/null 2>&1; then
            active_status="${GREEN}실행중${NC}"
        else
            active_status="${RED}정지됨${NC}"
        fi
        
        echo -e "$enabled_status, $active_status"
    done
}

show_manual() {
    echo -e "${YELLOW}수동 설치 가이드:${NC}"
    echo "────────────────────────────────────────"
    echo
    echo "1. Systemd 서비스 설치:"
    echo "   sudo $0 install"
    echo
    echo "2. 자동 시작 활성화:"
    echo "   sudo $0 enable"
    echo
    echo "3. 서비스 시작:"
    echo "   sudo systemctl start crawler-agent@3001"
    echo "   sudo systemctl start crawler-agent@3002"
    echo "   sudo systemctl start crawler-agent@3003"
    echo "   sudo systemctl start crawler-agent@3004"
    echo
    echo "4. 상태 확인:"
    echo "   $0 status"
    echo
    echo "5. 서비스 관리:"
    echo "   sudo systemctl stop crawler-agent@3001     # 정지"
    echo "   sudo systemctl restart crawler-agent@3001  # 재시작"
    echo "   sudo systemctl status crawler-agent@3001   # 상세 상태"
    echo
    echo "6. 로그 확인:"
    echo "   sudo journalctl -u crawler-agent@3001 -f   # 실시간 로그"
    echo "   sudo journalctl -u crawler-agent@3001      # 전체 로그"
    echo
    echo -e "${BLUE}참고: 관리 도구를 사용하면 더 쉽게 관리할 수 있습니다.${NC}"
    echo "      ./scripts/manage.sh"
}

# 메인 로직
case "$1" in
    install)
        install_services
        ;;
    enable)
        enable_auto_start
        ;;
    disable)
        disable_auto_start
        ;;
    status)
        show_status
        ;;
    manual)
        show_manual
        ;;
    *)
        show_usage
        ;;
esac