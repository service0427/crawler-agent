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
echo -e "${YELLOW}        Systemd Service Setup for Crawler Agent${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

show_usage() {
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  install-single     Install single agent service"
    echo "  install-multi      Install multi-agent services (3001-3004)"
    echo "  uninstall          Remove all agent services"
    echo "  status             Show service status"
    echo "  start [port]       Start service(s)"
    echo "  stop [port]        Stop service(s)"
    echo "  restart [port]     Restart service(s)"
    echo "  logs [port]        Show service logs"
    echo
    echo "Examples:"
    echo "  $0 install-single"
    echo "  $0 install-multi"
    echo "  $0 start 3001"
    echo "  $0 logs 3002"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This command requires root privileges. Please run with sudo.${NC}"
        exit 1
    fi
}

install_single() {
    check_root
    echo -e "${YELLOW}Installing single agent service...${NC}"
    
    # Update service file with correct paths
    sed "s|/home/tech/crawler/agent|$PROJECT_ROOT|g" $PROJECT_ROOT/config/crawler-agent.service > /tmp/crawler-agent.service
    
    # Copy to systemd directory
    cp /tmp/crawler-agent.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Single agent service installed${NC}"
    echo
    echo "To enable auto-start on boot:"
    echo "  sudo systemctl enable crawler-agent"
    echo
    echo "To start the service:"
    echo "  sudo systemctl start crawler-agent"
}

install_multi() {
    check_root
    echo -e "${YELLOW}Installing multi-agent services...${NC}"
    
    # Update template service file with correct paths
    sed "s|/home/tech/crawler/agent|$PROJECT_ROOT|g" $PROJECT_ROOT/config/crawler-agent@.service > /tmp/crawler-agent@.service
    
    # Copy to systemd directory
    cp /tmp/crawler-agent@.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Multi-agent service template installed${NC}"
    echo
    echo "To enable agents on boot (ports 3001-3004):"
    for port in 3001 3002 3003 3004; do
        echo "  sudo systemctl enable crawler-agent@$port"
    done
    echo
    echo "To start all agents:"
    echo "  $0 start"
}

uninstall() {
    check_root
    echo -e "${YELLOW}Uninstalling agent services...${NC}"
    
    # Stop all services
    systemctl stop crawler-agent 2>/dev/null
    for port in 3001 3002 3003 3004; do
        systemctl stop crawler-agent@$port 2>/dev/null
    done
    
    # Disable services
    systemctl disable crawler-agent 2>/dev/null
    for port in 3001 3002 3003 3004; do
        systemctl disable crawler-agent@$port 2>/dev/null
    done
    
    # Remove service files
    rm -f /etc/systemd/system/crawler-agent.service
    rm -f /etc/systemd/system/crawler-agent@.service
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Services uninstalled${NC}"
}

show_status() {
    echo -e "${YELLOW}Service Status:${NC}"
    echo "────────────────────────────────────────"
    
    # Check single agent service
    if systemctl list-unit-files | grep -q "^crawler-agent.service"; then
        echo -n "Single Agent: "
        systemctl is-active crawler-agent >/dev/null 2>&1 && echo -e "${GREEN}Active${NC}" || echo -e "${RED}Inactive${NC}"
    fi
    
    # Check multi-agent services
    if systemctl list-unit-files | grep -q "^crawler-agent@.service"; then
        for port in 3001 3002 3003 3004; do
            echo -n "Agent $port: "
            systemctl is-active crawler-agent@$port >/dev/null 2>&1 && echo -e "${GREEN}Active${NC}" || echo -e "${RED}Inactive${NC}"
        done
    fi
}

start_service() {
    check_root
    local port=$1
    
    if [ -z "$port" ]; then
        # Start all multi-agent services
        echo -e "${YELLOW}Starting all agents...${NC}"
        for p in 3001 3002 3003 3004; do
            echo -n "Starting agent on port $p... "
            systemctl start crawler-agent@$p
            sleep 1
            systemctl is-active crawler-agent@$p >/dev/null 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        done
    else
        # Start specific agent
        echo -e "${YELLOW}Starting agent on port $port...${NC}"
        systemctl start crawler-agent@$port
        systemctl is-active crawler-agent@$port >/dev/null 2>&1 && echo -e "${GREEN}✓ Started${NC}" || echo -e "${RED}✗ Failed${NC}"
    fi
}

stop_service() {
    check_root
    local port=$1
    
    if [ -z "$port" ]; then
        # Stop all services
        echo -e "${YELLOW}Stopping all agents...${NC}"
        systemctl stop crawler-agent 2>/dev/null
        for p in 3001 3002 3003 3004; do
            echo -n "Stopping agent on port $p... "
            systemctl stop crawler-agent@$p
            echo -e "${GREEN}✓${NC}"
        done
    else
        # Stop specific agent
        echo -e "${YELLOW}Stopping agent on port $port...${NC}"
        systemctl stop crawler-agent@$port
        echo -e "${GREEN}✓ Stopped${NC}"
    fi
}

restart_service() {
    check_root
    local port=$1
    
    if [ -z "$port" ]; then
        # Restart all services
        echo -e "${YELLOW}Restarting all agents...${NC}"
        for p in 3001 3002 3003 3004; do
            echo -n "Restarting agent on port $p... "
            systemctl restart crawler-agent@$p
            sleep 1
            systemctl is-active crawler-agent@$p >/dev/null 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        done
    else
        # Restart specific agent
        echo -e "${YELLOW}Restarting agent on port $port...${NC}"
        systemctl restart crawler-agent@$port
        systemctl is-active crawler-agent@$port >/dev/null 2>&1 && echo -e "${GREEN}✓ Restarted${NC}" || echo -e "${RED}✗ Failed${NC}"
    fi
}

show_logs() {
    local port=$1
    
    if [ -z "$port" ]; then
        # Show all logs
        echo -e "${YELLOW}Showing all agent logs (Ctrl+C to exit)...${NC}"
        journalctl -u "crawler-agent*" -f
    else
        # Show specific agent logs
        echo -e "${YELLOW}Showing logs for agent on port $port (Ctrl+C to exit)...${NC}"
        journalctl -u "crawler-agent@$port" -f
    fi
}

# Main logic
case "$1" in
    install-single)
        install_single
        ;;
    install-multi)
        install_multi
        ;;
    uninstall)
        uninstall
        ;;
    status)
        show_status
        ;;
    start)
        start_service $2
        ;;
    stop)
        stop_service $2
        ;;
    restart)
        restart_service $2
        ;;
    logs)
        show_logs $2
        ;;
    *)
        show_usage
        ;;
esac