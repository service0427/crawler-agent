# Installation Guide

이 문서는 Web Crawler Agent의 상세한 설치 가이드를 제공합니다.

## 설치 방법

### 1. 원격 설치 스크립트 (권장)

가장 빠르고 간단한 방법입니다:

```bash
# GitHub에서 직접 설치
curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash
```

이 스크립트는 다음을 자동으로 수행합니다:
- Node.js v18+ 설치 확인 및 설치
- 필요한 시스템 패키지 설치
- 소스 코드 다운로드
- 의존성 설치
- 기본 설정 파일 생성

### 2. Git Clone 설치

```bash
# 저장소 클론
git clone https://github.com/service0427/crawler-agent.git
cd crawler-agent

# 설치 스크립트 실행
chmod +x install-quick.sh
./install-quick.sh
```

### 3. 수동 설치

개별 단계를 직접 수행하려면:

```bash
# 1. 저장소 클론
git clone https://github.com/service0427/crawler-agent.git
cd crawler-agent

# 2. 의존성 설치
npm install

# 3. Playwright 브라우저 설치
npx playwright install chromium

# 4. 환경 설정
cp .env.example .env
# .env 파일 편집

# 5. 필요한 디렉토리 생성
mkdir -p logs data/users
```

## 업데이트

기존 설치를 업데이트하려면:

```bash
# 자동 업데이트
cd ~/crawler-agent
curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash
```

업데이트 시:
- 기존 `.env` 파일은 보존됩니다
- 실행 중인 에이전트는 재시작이 필요합니다
- 새로운 설정 옵션은 `.env.example`을 참고하세요

## 플랫폼별 설치

### Ubuntu/Debian

```bash
# 시스템 패키지 업데이트
sudo apt-get update
sudo apt-get install -y curl git

# 원격 설치
curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash
```

### CentOS/RHEL

```bash
# 시스템 패키지 업데이트
sudo yum update -y
sudo yum install -y curl git

# 원격 설치
curl -s https://raw.githubusercontent.com/service0427/crawler-agent/main/install-quick.sh | bash
```

### Windows

PowerShell을 관리자 권한으로 실행:

```powershell
# Git 설치 확인
git --version

# 저장소 클론
git clone https://github.com/service0427/crawler-agent.git
cd crawler-agent

# Node.js 설치 (https://nodejs.org 에서 다운로드)

# 의존성 설치
npm install

# Playwright 브라우저 설치
npx playwright install chromium

# 환경 설정
copy .env.example .env
notepad .env
```

## 문제 해결

### Node.js 버전 오류

```bash
# Node.js 버전 확인
node -v

# v18 미만인 경우 업데이트
curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Playwright 브라우저 오류

```bash
# 브라우저 재설치
npx playwright install chromium
npx playwright install-deps
```

### 권한 오류

```bash
# 스크립트 실행 권한 부여
chmod +x scripts/*.sh
```

## 설치 확인

설치가 완료되면 다음을 확인하세요:

```bash
# Node.js 버전
node -v  # v18 이상

# 의존성 설치 확인
npm list

# 설정 파일 확인
cat .env

# 테스트 실행
npm start
```