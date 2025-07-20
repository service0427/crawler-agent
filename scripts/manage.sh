#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 환경 변수 로드
if [ -f .env ]; then
    export $(cat .env | sed 's/#.*//g' | xargs)
fi

# 함수들
show_header() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}              웹 크롤러 에이전트 관리 도구${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

check_agent_status() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":${port}.*LISTEN.*node"; then
        local pid=$(netstat -tlnp 2>/dev/null | grep ":${port}.*LISTEN.*node" | awk '{print $7}' | cut -d'/' -f1)
        echo -e "${GREEN}실행중${NC} (PID: $pid)"
        return 0
    else
        echo -e "${RED}정지됨${NC}"
        return 1
    fi
}

show_status() {
    show_header
    echo -e "${YELLOW}에이전트 상태:${NC}"
    echo "────────────────────────────────────────"
    
    for port in 3001 3002 3003 3004; do
        echo -n "포트 $port 에이전트: "
        check_agent_status $port
    done
    
    echo
    echo -e "${YELLOW}시스템 리소스:${NC}"
    echo "────────────────────────────────────────"
    
    # Memory usage
    local mem_usage=$(ps aux | grep "node.*index.js" | grep -v grep | awk '{sum += $6} END {print sum/1024}')
    echo "총 메모리 사용량: ${mem_usage:-0} MB"
    
    # Chrome processes
    local chrome_count=$(pgrep -f "chrome|chromium" | wc -l)
    echo "Chrome 프로세스: $chrome_count"
    
    # Log sizes
    local log_size=$(du -sh logs 2>/dev/null | cut -f1)
    echo "로그 디렉토리 크기: ${log_size:-0}"
}

start_single_agent() {
    echo -e "${YELLOW}단일 에이전트 시작 중...${NC}"
    DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent.log 2>&1 &
    sleep 2
    
    if check_agent_status 3001 > /dev/null; then
        echo -e "${GREEN}✓ 에이전트가 성공적으로 시작되었습니다${NC}"
    else
        echo -e "${RED}✗ 에이전트 시작 실패${NC}"
        echo "자세한 내용은 logs/agent.log를 확인하세요"
    fi
}

start_multi_agents() {
    echo -e "${YELLOW}다중 에이전트 시작 중...${NC}"
    
    for i in {1..4}; do
        local port=$((3000 + i))
        echo -n "포트 $port에서 에이전트 $i 시작... "
        
        PORT=$port AGENT_ID=$i DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent$i.log 2>&1 &
        sleep 1
        
        if check_agent_status $port > /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
}

stop_all_agents() {
    echo -e "${YELLOW}모든 에이전트 정지 중...${NC}"
    
    # Kill by process name
    pkill -f "node.*src/index.js" 2>/dev/null
    
    # Kill by port if still running
    for port in 3001 3002 3003 3004; do
        local pid=$(netstat -tlnp 2>/dev/null | grep ":${port}.*LISTEN.*node" | awk '{print $7}' | cut -d'/' -f1)
        if [ ! -z "$pid" ]; then
            kill -9 $pid 2>/dev/null
        fi
    done
    
    sleep 1
    echo -e "${GREEN}✓ 모든 에이전트가 정지되었습니다${NC}"
}

view_logs() {
    echo -e "${YELLOW}로그 보기 선택:${NC}"
    echo "1) 모든 로그 (실시간)"
    echo "2) 에이전트 1 로그"
    echo "3) 에이전트 2 로그"
    echo "4) 에이전트 3 로그"
    echo "5) 에이전트 4 로그"
    echo "6) 모든 로그 삭제"
    echo "0) 메인 메뉴로 돌아가기"
    
    read -p "선택하세요: " log_choice
    
    case $log_choice in
        1) tail -f logs/*.log ;;
        2) tail -f logs/agent1.log ;;
        3) tail -f logs/agent2.log ;;
        4) tail -f logs/agent3.log ;;
        5) tail -f logs/agent4.log ;;
        6) 
            read -p "정말로 모든 로그를 삭제하시겠습니까? (y/N): " confirm
            if [ "$confirm" = "y" ]; then
                rm -f logs/*.log
                echo -e "${GREEN}✓ 로그가 삭제되었습니다${NC}"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}잘못된 선택입니다${NC}" ;;
    esac
}

configure_agent() {
    echo -e "${YELLOW}환경 설정:${NC}"
    echo "────────────────────────────────────────"
    
    if [ -f .env ]; then
        echo -e "${GREEN}현재 설정 (.env):${NC}"
        cat .env | grep -E "^[^#]" | sed 's/=.*$/=***/'
        echo
        echo ".env 파일을 편집하여 설정을 변경하세요"
    else
        echo -e "${RED}.env 파일을 찾을 수 없습니다!${NC}"
        echo ".env.example을 .env로 복사하고 설정하세요"
    fi
}

show_menu() {
    echo
    echo -e "${YELLOW}메인 메뉴:${NC}"
    echo "────────────────────────────────────────"
    echo "1) 상태 보기"
    echo "2) 단일 에이전트 시작"
    echo "3) 다중 에이전트 시작 (4개)"
    echo "4) 모든 에이전트 정지"
    echo "5) 모든 에이전트 재시작"
    echo "6) 로그 보기"
    echo "7) 환경 설정"
    echo "8) 의존성 설치/업데이트"
    echo "0) 종료"
    echo
    read -p "선택하세요: " choice
}

install_update() {
    echo -e "${YELLOW}의존성 설치/업데이트 중...${NC}"
    npm install
    npx playwright install chromium
    echo -e "${GREEN}✓ 의존성이 업데이트되었습니다${NC}"
}

# Main loop
main() {
    while true; do
        show_header
        show_status
        show_menu
        
        case $choice in
            1) ;; # Status already shown
            2) start_single_agent ;;
            3) start_multi_agents ;;
            4) stop_all_agents ;;
            5) 
                stop_all_agents
                sleep 2
                start_multi_agents
                ;;
            6) view_logs ;;
            7) configure_agent ;;
            8) install_update ;;
            0) 
                echo "안녕히가세요!"
                exit 0
                ;;
            *)
                echo -e "${RED}잘못된 선택입니다${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo
            read -p "계속하려면 Enter를 누르세요..."
        fi
    done
}

# Run main function
main