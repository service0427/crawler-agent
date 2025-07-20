# Web Crawler Agent

분산 웹 크롤러 시스템의 에이전트 구성요소입니다. Playwright를 사용하여 Chrome 브라우저를 자동화하고, 중앙 허브와 통신하여 크롤링 작업을 수행합니다.

> **Note**: 이 프로젝트는 활발히 개발 중입니다. 최신 업데이트는 [GitHub Releases](https://github.com/service0427/crawler-agent/releases)를 확인하세요.

## 주요 기능

- **브라우저 자동화**: Playwright 기반 Chrome 브라우저 제어
- **워크플로우 시스템**: 유연한 크롤링 작업 정의 및 실행
- **허브 통신**: HTTPS를 통한 안전한 허브-에이전트 통신
- **멀티 에이전트**: 단일 서버에서 여러 에이전트 인스턴스 실행
- **크로스 플랫폼**: Windows, Linux, macOS 지원
- **MCP 통합**: Model Context Protocol을 통한 GitHub API 연동

## 시스템 요구사항

- Node.js v18 이상
- Google Chrome 브라우저 (설치 스크립트 포함)
- 최소 2GB RAM (에이전트당)
- 최소 1GB 디스크 공간

## 빠른 시작

### 원격 설치 (curl 사용)

```bash
# 원격 스크립트로 자동 설치
curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash

# 설치 중:
# - 기존 설치 발견 시 선택 옵션 제공
# - 에이전트 ID 입력 프롬프트
# - Google Chrome 자동 설치

# 설치 후 허브 설정
cd ~/crawler-agent
nano .env  # HUB_URL과 HUB_SECRET을 실제 값으로 변경

# 에이전트 실행
./scripts/manage.sh
```

### 기타 설치 방법

<details>
<summary>클릭하여 확장</summary>

#### Git Clone 설치
```bash
# 저장소 클론
git clone https://github.com/service0427/crawler-agent.git
cd crawler-agent

# 설치 스크립트 실행
./install-quick.sh
```

#### Windows
```powershell
# 저장소 클론
git clone https://github.com/service0427/crawler-agent.git
cd crawler-agent

# PowerShell 관리자 권한으로 실행
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\install.ps1

# 환경 설정
copy .env.example .env
notepad .env  # HUB_SECRET을 실제 키로 변경

# 에이전트 실행
npm start
```
</details>

## 🚀 실제 배포용 빠른 가이드

> **보안 주의**: 실제 배포 시 반드시 `.env` 파일의 기본값을 변경하고, 적절한 방화벽 규칙을 설정하세요.

### Linux 서버에 배포

```bash
# 1. 자동 설치 (curl 명령 하나로 모든 것을 설치)
curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash

# 설치 중 입력 항목:
# - 기존 설치 발견 시: 업데이트(1) 또는 새 디렉토리(2) 선택
# - 에이전트 ID: 기본값 또는 사용자 정의 ID 입력

# 2. 허브 연결 설정 (필수!)
cd ~/crawler-agent
nano .env
# HUB_URL과 HUB_SECRET을 실제 값으로 수정

# 3. 에이전트 실행
./scripts/manage.sh  # 메뉴에서 원하는 옵션 선택

# 4. 서비스로 등록 (선택사항)
sudo ./scripts/systemd-setup.sh install-multi
```

### ⚠️ 필수 설정 항목

`.env` 파일에서 **반드시** 다음 항목을 수정해야 합니다:

```env
# 에이전트 설정
PORT=3001                    # 에이전트 포트
AGENT_ID=agent-1            # 고유 에이전트 ID

# 허브 연결
HUB_URL=https://your-hub-domain.com:8443     # 허브 URL
HUB_SECRET=your-hub-secret-key        # 인증 키 (실제 키로 교체 필요)

# 브라우저 설정
HEADLESS=false              # 헤드리스 모드 (true/false)
```

## 멀티 에이전트 실행

### Linux/macOS

```bash
# 4개 에이전트 동시 실행 (포트 3001-3004)
./scripts/start-multi-agents.sh

# 관리 도구로 제어
./scripts/manage.sh
```

### Windows

```powershell
# PowerShell에서 실행
.\scripts\start-multi-agents.ps1

# 또는 배치 파일 사용
start-multi-agents.bat
```

## 시스템 서비스로 실행

### Linux (systemd)

```bash
# 서비스 설치
sudo ./scripts/systemd-setup.sh install-multi

# 자동 시작 활성화
sudo systemctl enable crawler-agent@3001
sudo systemctl enable crawler-agent@3002
sudo systemctl enable crawler-agent@3003
sudo systemctl enable crawler-agent@3004

# 서비스 시작
sudo systemctl start crawler-agent@3001
```

### Windows (PM2)

```powershell
# PM2 설치
npm install -g pm2

# 에이전트 시작
pm2 start src/index.js --name crawler-agent

# 시스템 시작 시 자동 실행
pm2 save
pm2 startup
```

## 워크플로우 개발

워크플로우는 `src/workflows` 디렉토리에 위치합니다.

### 사용 가능한 워크플로우

- **coupang-search**: 쿠팡 상품 검색 및 데이터 추출 (연관검색어 포함)
- **naver-shopping-store**: 네이버 쇼핑 Smart Store 검색
- **naver-shopping-compare**: 네이버 쇼핑 가격비교 검색

### 개발 도구 사용법

```bash
# 워크플로우 테스트 (개발 모드)
node dev-workflow.js coupang-search keyword="노트북" limit=100

# 네이버 쇼핑 테스트
node dev-workflow.js naver-shopping-store keyword="스마트폰"

# 개발 옵션
node dev-workflow.js coupang-search keyword="마우스" --port=7777 --user-agent
```

### 기본 워크플로우 구조

```javascript
module.exports = {
  name: 'example-workflow',
  description: '워크플로우 설명',
  
  async execute(page, params) {
    const { keyword, limit } = params;
    
    // 페이지 이동
    await page.goto(`https://example.com/search?q=${keyword}`);
    
    // 데이터 추출
    const data = await page.evaluate(() => {
      return document.title;
    });
    
    return { 
      keyword: keyword,
      count: 1,
      products: [data],
      timestamp: new Date().toISOString()
    };
  }
};
```

## 모니터링

### 로그 확인

```bash
# 실시간 로그 보기
tail -f logs/agent.log

# 특정 에이전트 로그
tail -f logs/agent1.log
```

### 상태 확인

```bash
# 관리 도구 사용 (한글 인터페이스)
./scripts/manage.sh

# systemd 상태
sudo systemctl status crawler-agent@3001
```

### 관리 도구 주요 기능

`./scripts/manage.sh`를 실행하면 다음 메뉴가 제공됩니다:

1. 상태 보기 - 에이전트 및 시스템 리소스 상태
2. 단일 에이전트 시작 - 포트 3001에서 단일 에이전트 실행
3. 다중 에이전트 시작 (4개) - 포트 3001-3004에서 4개 에이전트 실행
4. 모든 에이전트 정지 - 실행 중인 모든 에이전트 종료
5. 모든 에이전트 재시작 - 정지 후 다중 에이전트 시작
6. 로그 보기 - 실시간 로그 모니터링 및 로그 삭제
7. 환경 설정 - .env 파일 상태 확인
8. 의존성 설치/업데이트 - npm 패키지 및 Playwright 업데이트

## 문제 해결

### 포트 충돌

```bash
# 사용 중인 포트 확인
netstat -tlnp | grep 3001

# 프로세스 종료
kill -9 <PID>
```

### Chrome 실행 오류

```bash
# Linux에서 의존성 설치
sudo apt-get install chromium-browser
npx playwright install-deps chromium
```

### 허브 연결 실패

1. `.env` 파일의 `HUB_URL`과 `HUB_SECRET` 확인
2. 네트워크 연결 상태 확인
3. 허브 서버 상태 확인

## 디렉토리 구조

```
crawler-agent/
├── src/                    # 소스 코드
│   ├── index.js           # 메인 에이전트 서버
│   └── workflows/         # 워크플로우 모듈
├── scripts/               # 관리 스크립트
│   ├── install.sh         # Linux 설치
│   ├── install.ps1        # Windows 설치
│   └── manage.sh          # 통합 관리 도구
├── config/                # 설정 파일
│   ├── default.json       # 기본 설정
│   └── *.service          # systemd 서비스
├── logs/                  # 로그 파일
├── data/                  # 데이터 저장
│   └── users/            # 브라우저 사용자 데이터
└── .env                   # 환경 변수

```

## API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/` | 에이전트 상태 확인 |
| GET | `/health` | 헬스 체크 |
| POST | `/workflow` | 워크플로우 실행 |
| GET | `/workflows` | 사용 가능한 워크플로우 목록 |

## 보안 고려사항

- 허브와의 통신은 HTTPS와 API 키로 보호됨
- 에이전트는 허브의 IP 주소를 검증함 (옵션)
- 민감한 정보는 환경 변수로 관리
- 로그에 비밀번호나 API 키가 노출되지 않도록 주의

## 기여하기

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 라이선스

이 프로젝트는 MIT 라이선스로 배포됩니다.

## 지원

문제가 발생하거나 질문이 있으시면 [Issues](https://github.com/service0427/crawler-agent/issues)에 등록해주세요.