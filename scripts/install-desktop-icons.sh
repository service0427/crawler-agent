#!/bin/bash

# 바탕화면 아이콘 설치 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}          크롤러 에이전트 바탕화면 아이콘 설치${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

# 바탕화면 디렉토리 확인 및 생성
DESKTOP_DIR=""
if [ -d "$HOME/바탕화면" ]; then
    DESKTOP_DIR="$HOME/바탕화면"
elif [ -d "$HOME/Desktop" ]; then
    DESKTOP_DIR="$HOME/Desktop"
else
    echo -e "${YELLOW}바탕화면 디렉토리를 생성합니다...${NC}"
    mkdir -p "$HOME/Desktop"
    DESKTOP_DIR="$HOME/Desktop"
fi

echo -e "${GREEN}바탕화면 디렉토리: $DESKTOP_DIR${NC}"

# 아이콘 파일 경로 업데이트
update_desktop_file() {
    local src_file="$1"
    local dest_file="$2"
    
    # 경로를 현재 프로젝트 경로로 업데이트
    sed "s|/home/tech/crawler/agent|$PROJECT_ROOT|g" "$src_file" > "$dest_file"
    
    # 아이콘 경로 설정
    if [ -f "$PROJECT_ROOT/icons/crawler-agent-48.png" ]; then
        sed -i "s|Icon=.*|Icon=$PROJECT_ROOT/icons/crawler-agent-48.png|g" "$dest_file"
    elif [ -f "$PROJECT_ROOT/icons/crawler-agent.svg" ]; then
        sed -i "s|Icon=.*|Icon=$PROJECT_ROOT/icons/crawler-agent.svg|g" "$dest_file"
    fi
    
    # 실행 권한 부여
    chmod +x "$dest_file"
}

# 시스템 애플리케이션 디렉토리에 설치
install_to_applications() {
    echo -e "${YELLOW}시스템 애플리케이션 메뉴에 설치 중...${NC}"
    
    # 아이콘을 시스템 아이콘 디렉토리에 복사
    if [ -f "$PROJECT_ROOT/icons/crawler-agent-48.png" ]; then
        sudo cp "$PROJECT_ROOT/icons/crawler-agent-48.png" /usr/share/pixmaps/crawler-agent.png 2>/dev/null || true
    fi
    
    # .desktop 파일들을 시스템에 설치
    for desktop_file in "$PROJECT_ROOT/config"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            local filename=$(basename "$desktop_file")
            local temp_file="/tmp/$filename"
            
            # 경로 업데이트
            update_desktop_file "$desktop_file" "$temp_file"
            
            # 시스템 아이콘 사용으로 업데이트
            if [ -f "/usr/share/pixmaps/crawler-agent.png" ]; then
                sed -i "s|Icon=.*|Icon=crawler-agent|g" "$temp_file"
            fi
            
            # 시스템 디렉토리에 복사
            sudo cp "$temp_file" "/usr/share/applications/" 2>/dev/null || true
            rm -f "$temp_file"
            
            echo -e "  ✓ $filename"
        fi
    done
    
    # 데스크톱 데이터베이스 업데이트
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
}

# 바탕화면에 단축 아이콘 설치
install_to_desktop() {
    echo -e "${YELLOW}바탕화면에 단축 아이콘 설치 중...${NC}"
    
    # GUI 관리자 아이콘 (메인)
    cat > "$DESKTOP_DIR/크롤러 에이전트 관리자.desktop" << EOF
[Desktop Entry]
Name=크롤러 에이전트 관리자
Comment=웹 크롤러 에이전트를 관리하는 GUI 도구입니다
Icon=$PROJECT_ROOT/icons/crawler-agent-48.png
Exec=$PROJECT_ROOT/scripts/gui-manager.sh
Terminal=false
Type=Application
Categories=System;Monitor;
StartupNotify=true
EOF
    chmod +x "$DESKTOP_DIR/크롤러 에이전트 관리자.desktop"
    
    # 터미널 관리자 아이콘
    cat > "$DESKTOP_DIR/크롤러 터미널 관리자.desktop" << EOF
[Desktop Entry]
Name=크롤러 터미널 관리자
Comment=터미널에서 크롤러 에이전트를 관리합니다
Icon=utilities-terminal
Exec=$PROJECT_ROOT/scripts/manage.sh
Terminal=true
Type=Application
Categories=System;Monitor;
StartupNotify=true
EOF
    chmod +x "$DESKTOP_DIR/크롤러 터미널 관리자.desktop"
    
    # 빠른 시작 아이콘
    cat > "$DESKTOP_DIR/크롤러 빠른 시작.desktop" << EOF
[Desktop Entry]
Name=크롤러 빠른 시작
Comment=크롤러 에이전트 4개를 즉시 시작합니다
Icon=media-playback-start
Exec=sh -c 'cd $PROJECT_ROOT && PORT=3001 AGENT_ID=1 DISPLAY=\${DISPLAY:-:0} nohup node src/index.js > logs/agent1.log 2>&1 & PORT=3002 AGENT_ID=2 DISPLAY=\${DISPLAY:-:0} nohup node src/index.js > logs/agent2.log 2>&1 & PORT=3003 AGENT_ID=3 DISPLAY=\${DISPLAY:-:0} nohup node src/index.js > logs/agent3.log 2>&1 & PORT=3004 AGENT_ID=4 DISPLAY=\${DISPLAY:-:0} nohup node src/index.js > logs/agent4.log 2>&1 & notify-send "크롤러 에이전트" "4개 에이전트가 시작되었습니다"'
Terminal=false
Type=Application
Categories=System;Network;
StartupNotify=true
EOF
    chmod +x "$DESKTOP_DIR/크롤러 빠른 시작.desktop"
    
    # 자동 시작 설정 아이콘
    cat > "$DESKTOP_DIR/크롤러 자동 시작 설정.desktop" << EOF
[Desktop Entry]
Name=크롤러 자동 시작 설정
Comment=부팅 시 크롤러 에이전트 자동 시작을 설정합니다
Icon=preferences-system
Exec=gnome-terminal -- bash -c 'cd $PROJECT_ROOT && ./scripts/auto-setup.sh manual && echo && echo "계속하려면 Enter를 누르세요..." && read'
Terminal=false
Type=Application
Categories=System;Settings;
StartupNotify=true
EOF
    chmod +x "$DESKTOP_DIR/크롤러 자동 시작 설정.desktop"
    
    echo -e "  ✓ 크롤러 에이전트 관리자.desktop"
    echo -e "  ✓ 크롤러 터미널 관리자.desktop"
    echo -e "  ✓ 크롤러 빠른 시작.desktop"
    echo -e "  ✓ 크롤러 자동 시작 설정.desktop"
}

# 제거 함수
uninstall_icons() {
    echo -e "${YELLOW}바탕화면 아이콘 제거 중...${NC}"
    
    # 바탕화면에서 제거
    rm -f "$DESKTOP_DIR"/크롤러*.desktop
    
    # 시스템에서 제거
    sudo rm -f /usr/share/applications/crawler-agent*.desktop 2>/dev/null || true
    sudo rm -f /usr/share/pixmaps/crawler-agent.png 2>/dev/null || true
    
    echo -e "${GREEN}✓ 아이콘이 제거되었습니다${NC}"
}

# 메인 로직
case "$1" in
    "uninstall")
        uninstall_icons
        ;;
    "system-only")
        install_to_applications
        echo -e "${GREEN}✓ 시스템 애플리케이션 메뉴에 설치 완료${NC}"
        ;;
    "desktop-only")
        install_to_desktop
        echo -e "${GREEN}✓ 바탕화면에 아이콘 설치 완료${NC}"
        ;;
    *)
        # 기본: 둘 다 설치
        install_to_applications
        install_to_desktop
        
        echo
        echo -e "${GREEN}✓ 설치 완료!${NC}"
        echo
        echo -e "${BLUE}설치된 아이콘들:${NC}"
        echo "  📱 크롤러 에이전트 관리자 (GUI)"
        echo "  💻 크롤러 터미널 관리자 (터미널)"
        echo "  🚀 크롤러 빠른 시작"
        echo "  ⚙️  크롤러 자동 시작 설정"
        echo
        echo -e "${YELLOW}사용법:${NC}"
        echo "  - 바탕화면 아이콘을 더블클릭하여 실행"
        echo "  - 애플리케이션 메뉴에서 '크롤러'로 검색"
        echo
        echo -e "${BLUE}자동 시작 설정:${NC}"
        echo "  sudo $PROJECT_ROOT/scripts/auto-setup.sh install"
        echo "  sudo $PROJECT_ROOT/scripts/auto-setup.sh enable"
        ;;
esac