# MCP (Model Context Protocol) Integration Guide

## 개요

이 프로젝트에는 MCP(Model Context Protocol)가 통합되어 GitHub API와 상호작용할 수 있습니다.

## 설정

### 1. 의존성 설치

```bash
npm install
```

MCP 관련 의존성:
- `@modelcontextprotocol/sdk`: MCP SDK
- `@octokit/rest`: GitHub API 클라이언트
- `zod`: 스키마 검증

### 2. 환경 변수 설정

`.env` 파일에 GitHub 토큰 추가:

```env
# GitHub 설정
GITHUB_TOKEN=your-github-personal-access-token
```

## 사용 방법

### 1. MCP 상태 확인

```bash
# dev-workflow.js를 사용하여 MCP 서버 상태 확인
node dev-workflow.js mcp-status
```

### 2. GitHub MCP 워크플로우 사용

#### 저장소 검색
```bash
node dev-workflow.js github-mcp action=search query="language:javascript stars:>1000"
```

#### 특정 저장소 정보 가져오기
```bash
node dev-workflow.js github-mcp action=get-repo owner=microsoft repo=vscode
```

#### 이슈 목록 조회
```bash
node dev-workflow.js github-mcp action=list-issues owner=microsoft repo=vscode state=open
```

#### 이슈 생성
```bash
node dev-workflow.js github-mcp action=create-issue owner=your-username repo=your-repo title="Test issue" body="This is a test"
```

#### 파일 내용 가져오기
```bash
node dev-workflow.js github-mcp action=get-file owner=microsoft repo=vscode path=README.md
```

## 구조

```
src/
├── mcp/
│   ├── github-server.js      # MCP GitHub 서버 구현
│   └── mcp-integration.js    # MCP 통합 관리자
└── workflows/
    ├── github-mcp.js         # GitHub MCP 워크플로우
    └── mcp-status.js         # MCP 상태 확인 워크플로우
```

## API 엔드포인트

### POST /workflow/run

MCP 워크플로우 실행:

```json
{
  "name": "github-mcp",
  "params": {
    "action": "search",
    "query": "language:javascript",
    "sort": "stars",
    "order": "desc",
    "per_page": 10
  }
}
```

## 지원되는 GitHub 작업

1. **search**: 저장소 검색
   - Parameters: query, sort, order, per_page

2. **get-repo**: 저장소 정보 조회
   - Parameters: owner, repo

3. **list-issues**: 이슈 목록 조회
   - Parameters: owner, repo, state, labels, per_page

4. **create-issue**: 이슈 생성
   - Parameters: owner, repo, title, body, labels

5. **get-file**: 파일 내용 조회
   - Parameters: owner, repo, path, ref

## 확장 가능성

MCP 통합은 다른 서비스로도 확장 가능합니다:
- Slack MCP 서버
- Database MCP 서버
- File System MCP 서버
- 기타 커스텀 MCP 서버

새로운 MCP 서버를 추가하려면:
1. `src/mcp/` 디렉토리에 새 서버 파일 생성
2. `mcp-integration.js`에 서버 초기화 코드 추가
3. 해당 워크플로우 파일 생성

## 문제 해결

1. **"GitHub client not initialized" 에러**
   - `.env` 파일에 `GITHUB_TOKEN`이 설정되어 있는지 확인
   - 토큰이 유효한지 확인

2. **MCP 서버가 시작되지 않음**
   - 콘솔 로그에서 에러 메시지 확인
   - 필요한 의존성이 모두 설치되었는지 확인

3. **권한 에러**
   - GitHub 토큰의 권한 확인 (repo, read:org 등)
   - 프라이빗 저장소 접근 시 추가 권한 필요