# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

This is a distributed web crawler agent that communicates with an external hub server.

## Development Setup

1. **Install Dependencies**:
   ```bash
   cd agent && npm install
   # Or use the install script
   ./scripts/install.sh
   ```

2. **Configure Environment**:
   ```bash
   cp .env.example .env
   # Edit .env with hub URL and API key
   ```

3. **Run Agent**:
   ```bash
   npm start  # Single agent on port 3001
   # Or use management script
   ./scripts/manage.sh
   ```

## Architecture Overview

### Agent (Default Port 3001)
- Playwright-based Chrome browser automation
- Runs Chrome in non-headless mode
- Stores user data in `data/users/user_${port}` directory
- Automatic registration with hub
- Heartbeat every 10 seconds
- Reports status to Hub (ready, navigating, completed, error)

### Hub Connection
- Hub URL: Configured in .env (e.g., https://your-hub-domain.com:8443)
- Authentication: X-API-Key header with secret from .env
- Automatic re-registration on 404 errors
- HTTPS with self-signed certificate support

### Communication Flow
1. Agent starts and registers with hub
2. Agent sends heartbeat every 10 seconds
3. Hub sends workflow requests to agent
4. Agent executes workflow using Playwright
5. Agent returns results to hub

## Project Structure

```
agent/
├── src/
│   ├── index.js         # Main agent server
│   └── workflows/       # Workflow modules
├── scripts/             # Management scripts
├── config/              # Configuration files
├── logs/                # Log files
└── data/                # User data and storage
```

## Key Files

- `src/index.js`: Main agent server with Playwright integration
- `src/workflows/`: Workflow modules for different crawling tasks
- `scripts/manage.sh`: Unified management tool for agents
- `config/default.json`: Default configuration values
- `.env`: Environment-specific configuration

## Common Development Tasks

### Adding New Workflows
Create new module in `src/workflows/` directory.

### Running Multiple Agents
```bash
# Start agents on ports 3001-3004
./scripts/manage.sh
# 옵션 3 선택 (다중 에이전트 시작)
```

### Development Tools
```bash
# Development workflow testing
node dev-workflow.js coupang-search keyword="노트북" limit=100
node dev-workflow.js naver-shopping-store keyword="노트북"

# Options
--port=7777          # Use specific port for user profile
--user-agent         # Enable custom user agent
```

### Monitoring Logs
```bash
tail -f logs/agent.log
# 또는 manage.sh 옵션 6 사용
```

### Management Script (Korean UI)
- `./scripts/manage.sh` - 한글 인터페이스로 제공
- 상태 확인, 에이전트 시작/정지, 로그 보기 등

### Available Workflows
- `coupang-search`: 쿠팡 상품 검색 및 데이터 추출
- `naver-shopping-store`: 네이버 쇼핑 Smart Store 검색
- `naver-shopping-compare`: 네이버 쇼핑 가격비교 검색

### Systemd Service (Linux)
```bash
sudo ./scripts/systemd-setup.sh install-multi
sudo systemctl start crawler-agent@3001
```