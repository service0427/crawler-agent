#!/usr/bin/env node

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// 명령줄 인수 파싱
const args = process.argv.slice(2);
if (args.length < 1) {
  console.log('Usage: node dev-workflow.js <workflow-name> [param1=value1] [param2=value2] ...');
  console.log('Example: node dev-workflow.js coupang-search keyword="노트북" limit=100');
  console.log('\nAvailable workflows:');
  console.log('  - coupang-search');
  console.log('  - naver-shopping-store');
  console.log('  - naver-shopping-compare');
  console.log('  - sample-extract');
  console.log('\nOptions:');
  console.log('  --port=<port>  Use specific user profile (default: 9999)');
  console.log('  --user-agent   Use custom user agent (for bot detection testing)');
  console.log('\nNote: User profiles are stored in dev-users/ directory');
  process.exit(1);
}

// 워크플로우 이름과 파라미터 분리
let workflowName = '';
const params = {};
let port = 9999; // 개발용 포트
let useUserAgent = false; // userAgent 사용 여부

// 먼저 워크플로우 이름 찾기 (--로 시작하지 않고 =를 포함하지 않는 첫 번째 인수)
for (const arg of args) {
  if (!arg.startsWith('--') && !arg.includes('=')) {
    workflowName = arg;
    break;
  }
}

// 나머지 인수 처리
for (const arg of args) {
  if (arg.startsWith('--')) {
    // 옵션 처리
    if (arg.startsWith('--port=')) {
      port = parseInt(arg.split('=')[1]);
    } else if (arg === '--user-agent') {
      useUserAgent = true;
    }
  } else if (arg.includes('=') && arg !== workflowName) {
    // 파라미터 처리
    const [key, value] = arg.split('=');
    const cleanValue = value.replace(/^["']|["']$/g, ''); // 따옴표 제거
    const numValue = Number(cleanValue);
    params[key] = isNaN(numValue) ? cleanValue : numValue;
  }
}

// 유저 데이터 디렉토리 설정 (개발용 별도 폴더)
const userDataDir = path.join(__dirname, 'dev-users', `user_${port}`);
console.log(`\n🚀 개발 모드 워크플로우 실행`);
console.log(`📁 사용자 프로필: ${userDataDir}`);
console.log(`🎯 워크플로우: ${workflowName}`);
console.log(`⚙️  파라미터:`, params);
console.log(`🔌 디버깅 포트: ${port + 1000}`);
if (useUserAgent) console.log(`🤖 커스텀 UserAgent: 활성화`);
console.log('-------------------\n');

async function runWorkflow() {
  let browser = null;
  let context = null;
  let page = null;
  
  try {
    // 유저 데이터 디렉토리 생성
    if (!fs.existsSync(userDataDir)) {
      fs.mkdirSync(userDataDir, { recursive: true });
      console.log(`✅ 유저 디렉토리 생성됨: ${userDataDir}`);
    }
    
    // xvfb 설정
    if (process.platform === 'linux') {
      process.env.DISPLAY = process.env.DISPLAY || ':0';
      console.log(`🖥️  DISPLAY 설정: ${process.env.DISPLAY}`);
    }
    
    // 브라우저 실행 (항상 GUI 모드)
    console.log('🌐 Chrome 브라우저 시작 중...');
    
    // 개발 모드는 화면 중앙에 적당한 크기로 배치
    const windowWidth = 1200;
    const windowHeight = 800;
    const windowX = Math.floor((1920 - windowWidth) / 2); // 화면 중앙
    const windowY = Math.floor((1080 - windowHeight) / 2);
    
    browser = await chromium.launch({
      headless: false, // 실제 Chrome은 항상 GUI 모드
      channel: 'chrome', // 시스템에 설치된 Chrome 사용
      args: [
        '--disable-setuid-sandbox',
        '--disable-blink-features=AutomationControlled',
        '--disable-features=AutomationControlled',
        `--remote-debugging-port=${port + 1000}`,
        '--remote-debugging-address=0.0.0.0',
        '--remote-allow-origins=*',
        `--window-position=${windowX},${windowY}`,
        `--window-size=${windowWidth},${windowHeight}`
      ]
    });
    
    // 컨텍스트 옵션 설정
    const contextOptions = {
      userDataDir: userDataDir,
      viewport: { width: windowWidth, height: windowHeight }
    };
    
    // userAgent 옵션이 설정된 경우에만 추가
    if (useUserAgent) {
      contextOptions.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      console.log('🤖 커스텀 UserAgent 사용');
    }
    
    // 컨텍스트 생성 (유저 데이터 포함)
    context = await browser.newContext(contextOptions);
    
    // 페이지 생성
    page = await context.newPage();
    console.log('✅ 브라우저 준비 완료\n');
    
    // 워크플로우 모듈 로드
    const workflowPath = path.join(__dirname, 'src', 'workflows', `${workflowName}.js`);
    if (!fs.existsSync(workflowPath)) {
      throw new Error(`워크플로우를 찾을 수 없습니다: ${workflowPath}`);
    }
    
    const workflow = require(workflowPath);
    console.log(`📋 워크플로우 로드됨: ${workflow.name || workflowName}`);
    console.log(`📝 설명: ${workflow.description || 'No description'}\n`);
    
    // 워크플로우 실행
    const startTime = Date.now();
    console.log('⏳ 워크플로우 실행 중...\n');
    
    const result = await workflow.execute(page, params);
    
    const endTime = Date.now();
    const duration = ((endTime - startTime) / 1000).toFixed(2);
    
    console.log(`\n✅ 워크플로우 완료! (${duration}초)`);
    
    // 결과 출력
    if (result) {
      if (result.count !== undefined) {
        console.log(`\n📊 결과 요약:`);
        console.log(`  - 검색어: ${result.keyword}`);
        console.log(`  - 추출 개수: ${result.count}`);
        console.log(`  - 총 페이지: ${result.totalPages || 1}`);
        console.log(`  - 타입: ${result.type || workflowName}`);
        if (result.searchUrl) console.log(`  - URL: ${result.searchUrl}`);
      }
    }
    
  } catch (error) {
    console.error('\n❌ 오류 발생:', error.message);
    console.error(error.stack);
  } finally {
    // 정리
    if (page) await page.close();
    if (context) await context.close();
    if (browser) await browser.close();
    console.log('✅ 정리 완료');
  }
}

// 실행
runWorkflow().catch(console.error);