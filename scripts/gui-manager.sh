#!/bin/bash

# GUI 환경에서 사용하는 크롤러 에이전트 관리 도구
# zenity를 사용한 그래픽 인터페이스

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# zenity 설치 확인
if ! command -v zenity &> /dev/null; then
    echo "zenity가 설치되지 않았습니다. 설치 중..."
    sudo apt-get update && sudo apt-get install -y zenity
fi

check_agent_status() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":${port}.*LISTEN.*node"; then
        return 0  # 실행 중
    else
        return 1  # 정지됨
    fi
}

get_status_summary() {
    local running=0
    local total=4
    
    for port in 3001 3002 3003 3004; do
        if check_agent_status $port; then
            ((running++))
        fi
    done
    
    echo "$running/$total 에이전트 실행 중"
}

show_status() {
    local status_text=""
    
    for port in 3001 3002 3003 3004; do
        if check_agent_status $port; then
            local pid=$(netstat -tlnp 2>/dev/null | grep ":${port}.*LISTEN.*node" | awk '{print $7}' | cut -d'/' -f1)
            status_text="$status_text포트 $port: 실행중 (PID: $pid)\n"
        else
            status_text="$status_text포트 $port: 정지됨\n"
        fi
    done
    
    # 시스템 리소스 정보 추가
    local mem_usage=$(ps aux | grep "node.*index.js" | grep -v grep | awk '{sum += $6} END {print sum/1024}')
    local chrome_count=$(pgrep -f "chrome|chromium" | wc -l)
    local log_size=$(du -sh logs 2>/dev/null | cut -f1)
    
    status_text="$status_text\n시스템 리소스:\n"
    status_text="$status_text메모리 사용량: ${mem_usage:-0} MB\n"
    status_text="$status_text크롬 프로세스: $chrome_count\n"
    status_text="$status_text로그 크기: ${log_size:-0}\n"
    
    zenity --info \
        --title="크롤러 에이전트 상태" \
        --text="$status_text" \
        --width=400 \
        --height=300
}

start_agents() {
    zenity --question \
        --title="에이전트 시작" \
        --text="4개의 크롤러 에이전트를 시작하시겠습니까?\n\n각 에이전트는 브라우저 창을 열고 화면의 4등분에 배치됩니다." \
        --width=350
    
    if [ $? -eq 0 ]; then
        # 기존 프로세스 정리
        pkill -f "node.*src/index.js" 2>/dev/null
        sleep 2
        
        # 4개 에이전트 시작
        PORT=3001 AGENT_ID=1 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent1.log 2>&1 &
        PORT=3002 AGENT_ID=2 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent2.log 2>&1 &
        PORT=3003 AGENT_ID=3 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent3.log 2>&1 &
        PORT=3004 AGENT_ID=4 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent4.log 2>&1 &
        
        # 시작 대기
        (
        echo "10"; sleep 1
        echo "30"; sleep 1
        echo "50"; sleep 1
        echo "70"; sleep 1
        echo "90"; sleep 1
        echo "100"
        ) | zenity --progress \
             --title="에이전트 시작 중..." \
             --text="크롤러 에이전트들을 시작하고 있습니다..." \
             --percentage=0 \
             --auto-close
        
        sleep 2
        
        # 결과 확인
        local started_count=0
        for port in 3001 3002 3003 3004; do
            if check_agent_status $port; then
                ((started_count++))
            fi
        done
        
        if [ $started_count -eq 4 ]; then
            zenity --info \
                --title="시작 완료" \
                --text="✅ 4개 에이전트가 모두 성공적으로 시작되었습니다!\n\n브라우저 창들이 화면에 4등분으로 배치되었습니다." \
                --width=350
        else
            zenity --warning \
                --title="시작 불완전" \
                --text="⚠️ $started_count/4개 에이전트만 시작되었습니다.\n\n로그를 확인해보세요." \
                --width=350
        fi
    fi
}

stop_agents() {
    zenity --question \
        --title="에이전트 정지" \
        --text="모든 크롤러 에이전트를 정지하시겠습니까?\n\n실행 중인 모든 브라우저 창이 닫힙니다." \
        --width=350
    
    if [ $? -eq 0 ]; then
        pkill -f "node.*src/index.js" 2>/dev/null
        sleep 2
        
        zenity --info \
            --title="정지 완료" \
            --text="✅ 모든 크롤러 에이전트가 정지되었습니다." \
            --width=300
    fi
}

restart_agents() {
    zenity --question \
        --title="에이전트 재시작" \
        --text="모든 크롤러 에이전트를 재시작하시겠습니까?\n\n기존 브라우저 창들이 닫히고 새로 시작됩니다." \
        --width=350
    
    if [ $? -eq 0 ]; then
        # 정지
        pkill -f "node.*src/index.js" 2>/dev/null
        sleep 3
        
        # 시작
        PORT=3001 AGENT_ID=1 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent1.log 2>&1 &
        PORT=3002 AGENT_ID=2 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent2.log 2>&1 &
        PORT=3003 AGENT_ID=3 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent3.log 2>&1 &
        PORT=3004 AGENT_ID=4 DISPLAY=${DISPLAY:-:0} nohup node src/index.js > logs/agent4.log 2>&1 &
        
        sleep 3
        
        zenity --info \
            --title="재시작 완료" \
            --text="✅ 모든 크롤러 에이전트가 재시작되었습니다." \
            --width=300
    fi
}

view_logs() {
    local log_choice=$(zenity --list \
        --title="로그 선택" \
        --text="확인할 로그를 선택하세요:" \
        --column="로그 타입" \
        "모든 로그 (실시간)" \
        "에이전트 1" \
        "에이전트 2" \
        "에이전트 3" \
        "에이전트 4" \
        "로그 삭제" \
        --width=300 \
        --height=300)
    
    case "$log_choice" in
        "모든 로그 (실시간)")
            gnome-terminal -- bash -c 'cd /home/tech/crawler/agent && echo "=== 모든 에이전트 로그 (Ctrl+C로 종료) ===" && tail -f logs/*.log'
            ;;
        "에이전트 1")
            gnome-terminal -- bash -c 'cd /home/tech/crawler/agent && echo "=== 에이전트 1 로그 (Ctrl+C로 종료) ===" && tail -f logs/agent1.log'
            ;;
        "에이전트 2")
            gnome-terminal -- bash -c 'cd /home/tech/crawler/agent && echo "=== 에이전트 2 로그 (Ctrl+C로 종료) ===" && tail -f logs/agent2.log'
            ;;
        "에이전트 3")
            gnome-terminal -- bash -c 'cd /home/tech/crawler/agent && echo "=== 에이전트 3 로그 (Ctrl+C로 종료) ===" && tail -f logs/agent3.log'
            ;;
        "에이전트 4")
            gnome-terminal -- bash -c 'cd /home/tech/crawler/agent && echo "=== 에이전트 4 로그 (Ctrl+C로 종료) ===" && tail -f logs/agent4.log'
            ;;
        "로그 삭제")
            zenity --question \
                --title="로그 삭제" \
                --text="정말로 모든 로그 파일을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다." \
                --width=350
            
            if [ $? -eq 0 ]; then
                rm -f logs/*.log
                zenity --info \
                    --title="삭제 완료" \
                    --text="✅ 모든 로그 파일이 삭제되었습니다." \
                    --width=300
            fi
            ;;
    esac
}

auto_start_setup() {
    gnome-terminal -- bash -c 'cd /home/tech/crawler/agent && ./scripts/auto-setup.sh manual && echo && echo "계속하려면 Enter를 누르세요..." && read'
}

# 메인 메뉴
while true; do
    local status_summary=$(get_status_summary)
    
    choice=$(zenity --list \
        --title="크롤러 에이전트 관리자" \
        --text="현재 상태: $status_summary\n\n수행할 작업을 선택하세요:" \
        --column="메뉴" \
        "상태 보기" \
        "에이전트 시작" \
        "에이전트 정지" \
        "에이전트 재시작" \
        "로그 보기" \
        "자동 시작 설정" \
        "종료" \
        --width=350 \
        --height=400)
    
    case "$choice" in
        "상태 보기")
            show_status
            ;;
        "에이전트 시작")
            start_agents
            ;;
        "에이전트 정지")
            stop_agents
            ;;
        "에이전트 재시작")
            restart_agents
            ;;
        "로그 보기")
            view_logs
            ;;
        "자동 시작 설정")
            auto_start_setup
            ;;
        "종료"|"")
            exit 0
            ;;
    esac
done