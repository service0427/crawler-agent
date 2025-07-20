require('dotenv').config();
const { chromium } = require('playwright');
const express = require('express');
const path = require('path');
const fs = require('fs');
const os = require('os');
const mcpIntegration = require('./mcp/mcp-integration');
const { withRetry, isNetworkError } = require('./utils/retry');

const PORT = process.env.PORT || process.argv[2] || 3001;
// AGENT_ID에 포트 번호가 없으면 자동으로 추가
let AGENT_ID = process.env.AGENT_ID || 'agent-1';
// 끝에 _숫자 패턴이 없으면 포트 추가
if (!AGENT_ID.match(/_\d+$/)) {
    AGENT_ID = `${AGENT_ID}_${PORT}`;
}
const HUB_SECRET = process.env.HUB_SECRET || 'your-hub-secret-key';
const ALLOWED_HUB_IPS = process.env.ALLOWED_HUB_IPS ? process.env.ALLOWED_HUB_IPS.split(',') : ['localhost', '127.0.0.1'];

let browser;
let context;

// Express 서버 설정
const app = express();
app.use(express.json({ 
  type: ['application/json', 'text/plain'], 
  limit: '10mb' 
}));

// 허브 인증 미들웨어 (현재는 비활성화 - 허브가 워크플로우 실행 시 인증을 보내지 않는 것 같음)
// TODO: 허브와 인증 방식 확인 필요
app.use((req, res, next) => {
  // 모든 요청 로깅
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} from ${req.ip}`);
  if (req.headers['x-api-key']) {
    console.log('X-API-Key header present');
  }
  if (req.headers['x-hub-auth']) {
    console.log('X-Hub-Auth header present');
  }
  
  // 현재는 모든 요청 허용
  next();
  
  // 아래는 나중에 활성화할 인증 코드
  /*
  // 헬스체크는 인증 없이 허용
  if (req.path === '/health' && req.method === 'GET') {
    return next();
  }
  
  const hubAuth = req.headers['x-hub-auth'] || req.headers['x-api-key'];
  const clientIP = req.ip || req.connection.remoteAddress;
  
  // 시크릿 키 검증
  if (hubAuth !== HUB_SECRET) {
    console.log(`Unauthorized request from ${clientIP}`);
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  next();
  */
});

async function initBrowser() {
  try {
    const userDataDir = `/home/tech/crawler/users/user_${PORT}`;
    
    // 화면 크기 기본값 (1920x1080 가정, 실제로는 시스템에서 감지 가능)
    const screenWidth = 1920;
    const screenHeight = 1080;
    const windowWidth = Math.floor(screenWidth / 2);
    const windowHeight = Math.floor(screenHeight / 2);
    
    // 포트에 따른 창 위치 계산 (4등분)
    let windowX = 0;
    let windowY = 0;
    
    const agentNum = parseInt(PORT) - 3000; // 3001 -> 1, 3002 -> 2, etc.
    switch (agentNum) {
      case 1: // 좌상
        windowX = 0;
        windowY = 0;
        break;
      case 2: // 우상
        windowX = windowWidth;
        windowY = 0;
        break;
      case 3: // 좌하
        windowX = 0;
        windowY = windowHeight;
        break;
      case 4: // 우하
        windowX = windowWidth;
        windowY = windowHeight;
        break;
      default: // 기타 포트는 순서대로 배치
        const position = (agentNum - 1) % 4;
        windowX = (position % 2) * windowWidth;
        windowY = Math.floor(position / 2) * windowHeight;
    }
    
    browser = await chromium.launch({
      headless: false,
      channel: 'chrome',
      args: [
        '--disable-setuid-sandbox',
        '--disable-blink-features=AutomationControlled',
        '--disable-features=AutomationControlled',
        '--remote-debugging-port=' + (parseInt(PORT) + 1000),
        '--remote-debugging-address=0.0.0.0',
        '--remote-allow-origins=*',
        `--window-position=${windowX},${windowY}`,
        `--window-size=${windowWidth},${windowHeight}`
      ]
    });
    
    context = await browser.newContext({
      userDataDir: userDataDir,
      viewport: { width: windowWidth, height: windowHeight }
    });
    
    // 빈 페이지 하나만 생성 (CDP 접근을 위해)
    await context.newPage();
   
    return true;
  } catch (error) {
    console.error('Browser initialization failed:', error.message);
    return false;
  }
}

// 매니저 통신용 엔드포인트
app.get('/health', (req, res) => {
  const memUsage = process.memoryUsage();
  res.json({
    success: true,
    agentId: AGENT_ID,
    port: PORT,
    cdpPort: parseInt(PORT) + 1000,
    status: browser ? 'ready' : 'disconnected',
    memoryUsage: memUsage,
    memoryMB: {
      rss: Math.round(memUsage.rss / 1024 / 1024),
      heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
      heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024)
    },
    uptime: Math.round(process.uptime())
  });
});

app.get('/memory', (req, res) => {
  const memUsage = process.memoryUsage();
  res.json({
    success: true,
    memory: {
      rss: memUsage.rss,
      heapTotal: memUsage.heapTotal,
      heapUsed: memUsage.heapUsed,
      external: memUsage.external,
      arrayBuffers: memUsage.arrayBuffers
    },
    memoryMB: Math.round(memUsage.rss / 1024 / 1024)
  });
});

app.post('/restart', async (req, res) => {
  try {
    console.log(`Agent ${AGENT_ID} restart requested`);
    
    if (browser) {
      await browser.close();
      browser = null;
      context = null;
    }
    
    const browserReady = await initBrowser();
    
    res.json({
      success: browserReady,
      message: browserReady ? 'Agent restarted successfully' : 'Agent restart failed'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.get('/info', (req, res) => {
  res.json({
    success: true,
    agent: {
      id: AGENT_ID,
      port: PORT,
      cdpPort: parseInt(PORT) + 1000,
      status: browser ? 'ready' : 'disconnected',
      uptime: process.uptime(),
      pid: process.pid
    }
  });
});

// Hub에서 요청하는 네비게이션 처리
app.post('/navigate', async (req, res) => {
  const { url, waitUntil = 'load' } = req.body;
  
  if (!url) {
    return res.status(400).json({ error: 'URL is required' });
  }
  
  try {
    if (!browser || !context) {
      return res.status(503).json({ error: 'Browser not ready' });
    }
    
    // 현재 페이지 가져오기 또는 새 페이지 생성
    const pages = context.pages();
    let page = pages[0];
    
    if (!page) {
      page = await context.newPage();
    }
    
    console.log(`Agent ${AGENT_ID} navigating to: ${url} (waitUntil: ${waitUntil})`);
    
    // waitUntil 옵션 처리 (Playwright용)
    const waitMap = {
      'load': 'load',
      'domcontentloaded': 'domcontentloaded',
      'networkidle0': 'networkidle',
      'networkidle2': 'networkidle',
      'networkidle': 'networkidle'
    };
    
    const gotoOptions = {
      timeout: 30000,
      waitUntil: waitMap[waitUntil] || 'load'
    };
    
    await page.goto(url, gotoOptions);
    
    const title = await page.title();
    const currentUrl = page.url();
    
    res.json({
      success: true,
      url: currentUrl,
      title: title
    });
    
  } catch (error) {
    console.error(`Agent ${AGENT_ID} navigation error:`, error);
    res.status(500).json({
      error: 'Navigation failed',
      message: error.message
    });
  }
});

// Hub에서 요청하는 코드 실행 처리
app.post('/execute', async (req, res) => {
  const { code } = req.body;
  
  if (!code) {
    return res.status(400).json({ error: 'Code is required' });
  }
  
  try {
    if (!browser || !context) {
      return res.status(503).json({ error: 'Browser not ready' });
    }
    
    // 현재 페이지 가져오기
    const pages = context.pages();
    const page = pages[0];
    
    if (!page) {
      return res.status(503).json({ error: 'No active page' });
    }
    
    console.log(`Agent ${AGENT_ID} executing code`);
    const result = await page.evaluate(code);
    
    res.json({
      success: true,
      result: result
    });
    
  } catch (error) {
    console.error(`Agent ${AGENT_ID} execution error:`, error);
    res.status(500).json({
      error: 'Execution failed',
      message: error.message
    });
  }
});

// 워크플로우 실행 엔드포인트 (허브가 사용하는 형식도 지원)
app.post(['/workflow/run', '/api/workflow/:workflowName'], async (req, res) => {
  const { module, workflow_name, params, request_id } = req.body || {};
  const workflowName = module || workflow_name || req.params.workflowName; // 세 가지 형식 모두 지원
  
  // params가 없으면 쿼리 파라미터에서 가져오기 시도
  const workflowParams = params || req.query || {};
  
  console.log(`[${new Date().toISOString()}] Workflow execution request:`, {
    workflow: workflowName,
    request_id,
    params: workflowParams
  });
  
  if (!workflowName) {
    return res.status(400).json({ error: 'Module or workflow_name is required' });
  }
  
  try {
    // 워크플로우 모듈 동적 로드
    const workflowPath = path.join(__dirname, 'workflows', `${workflowName}.js`);
    
    // 파일 존재 확인
    if (!fs.existsSync(workflowPath)) {
      return res.status(404).json({ 
        error: 'Workflow not found',
        message: `Workflow module '${module}' does not exist`
      });
    }
    
    const workflow = require(workflowPath);
    
    if (!browser || !context) {
      return res.status(503).json({ error: 'Browser not ready' });
    }
    
    // 현재 페이지 가져오기 또는 새로 생성
    const pages = context.pages();
    let page = pages[0];
    if (!page) {
      page = await context.newPage();
    }
    
    console.log(`Agent ${AGENT_ID} executing workflow: ${workflowName}`);
    
    // 워크플로우 실행
    const result = await workflow.execute(page, workflowParams);
    
    res.json({
      success: true,
      workflow_name: workflowName,
      request_id: request_id,
      result: result
    });
    
  } catch (error) {
    console.error(`Agent ${AGENT_ID} workflow error:`, error);
    res.status(500).json({
      success: false,
      workflow_name: workflowName,
      request_id: request_id,
      error: error.message
    });
  }
});

// 사용 가능한 워크플로우 목록
app.get('/workflow/list', (req, res) => {
  try {
    const workflowDir = path.join(__dirname, 'workflows');
    
    // 디렉토리 존재 확인
    if (!fs.existsSync(workflowDir)) {
      return res.json({
        success: true,
        workflows: []
      });
    }
    
    const files = fs.readdirSync(workflowDir)
      .filter(file => file.endsWith('.js'))
      .map(file => {
        const moduleName = file.replace('.js', '');
        try {
          const workflow = require(path.join(workflowDir, file));
          return {
            name: moduleName,
            description: workflow.description || 'No description'
          };
        } catch (error) {
          return {
            name: moduleName,
            description: 'Error loading workflow'
          };
        }
      });
    
    res.json({
      success: true,
      workflows: files
    });
  } catch (error) {
    console.error('Error listing workflows:', error);
    res.json({
      success: false,
      workflows: [],
      error: error.message
    });
  }
});

async function start() {
  const cdpPort = parseInt(PORT) + 1000;
  
  console.log(`Agent ${AGENT_ID} starting...`);
  console.log(`Port: ${PORT}, CDP Port: ${cdpPort}`);
  
  const browserReady = await initBrowser();
  
  if (browserReady) {
    console.log(`Agent ${AGENT_ID} browser ready on CDP port ${cdpPort}`);
    
    // MCP 통합 초기화
    await mcpIntegration.initialize();
    
    // HTTP 서버 시작 (허브 통신용)
    const BIND_ADDRESS = process.env.BIND_ADDRESS || '0.0.0.0';
    app.listen(PORT, BIND_ADDRESS, () => {
      console.log(`Agent ${AGENT_ID} HTTP server ready on ${BIND_ADDRESS}:${PORT}`);
      console.log(`Hub secret configured: ${HUB_SECRET ? 'Yes' : 'No'}`);
      
      // 허브에 에이전트 등록 시도
      if (process.env.HUB_URL) {
        registerToHub();
      }
    });
    
  } else {
    console.error(`Agent ${AGENT_ID} failed to start browser`);
    process.exit(1);
  }
}

// 허브에 에이전트 등록
let registeredAgentId = null;
let heartbeatInterval = null;

// HTTPS 설정 (개발 환경에서 자체 서명 인증서 허용)
const https = require('https');
const httpsAgent = new https.Agent({
  rejectUnauthorized: false
});

async function registerToHub() {
  const axios = require('axios');
  const HUB_URL = process.env.HUB_URL;
  
  if (!HUB_URL) return;
  
  try {
    // 네트워크 인터페이스에서 IP 가져오기
    const interfaces = os.networkInterfaces();
    let localIP = 'localhost';
    
    // 첫 번째 외부 IP 찾기
    for (const name of Object.keys(interfaces)) {
      for (const iface of interfaces[name]) {
        if (iface.family === 'IPv4' && !iface.internal) {
          localIP = iface.address;
          break;
        }
      }
      if (localIP !== 'localhost') break;
    }
    
    // 사용 가능한 워크플로우 목록 가져오기
    const workflowDir = path.join(__dirname, 'workflows');
    let workflows = [];
    
    if (fs.existsSync(workflowDir)) {
      workflows = fs.readdirSync(workflowDir)
        .filter(file => file.endsWith('.js'))
        .map(file => file.replace('.js', ''));
    }
    
    console.log(`Attempting to register agent to hub at ${HUB_URL}`);
    console.log(`Using Hub Secret: ${HUB_SECRET.substring(0, 20)}...`);
    console.log(`Agent details: name=${AGENT_ID}, host=${localIP}, port=${PORT}`);
    
    // 재시도 로직 적용
    const response = await withRetry(
      async () => {
        return await axios.post(`${HUB_URL}/api/agent/register`, {
          name: AGENT_ID,
          host: localIP,
          port: parseInt(PORT),
          version: '1.0.0',
          workflows: workflows
        }, {
          headers: {
            'X-API-Key': HUB_SECRET,
            'Content-Type': 'application/json'
          },
          httpsAgent: HUB_URL.startsWith('https') ? httpsAgent : undefined
        });
      },
      {
        maxAttempts: 5,
        delay: 2000,
        shouldRetry: (error) => {
          if (error.response && error.response.status >= 400 && error.response.status < 500) {
            return false; // 4xx 에러는 재시도하지 않음
          }
          return isNetworkError(error);
        },
        onRetry: (error, attempt) => {
          console.log(`Hub registration retry ${attempt}/5: ${error.message}`);
        }
      }
    );
    
    if (response.data) {
      console.log('Registration response:', response.data);
      
      if (response.data.success) {
        registeredAgentId = response.data.agent?.id || response.data.agentId;
        console.log(`Agent registered to hub successfully with ID: ${registeredAgentId}`);
        
        // 하트비트 시작 (10초마다)
        startHeartbeat();
      } else {
        console.log('Agent registration failed:', response.data.message || 'Unknown error');
      }
    } else {
      console.log('Agent registration failed: No response data');
    }
  } catch (error) {
    console.error('Failed to register to hub:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
    
    // 등록 실패 시 10초 후 재시도
    setTimeout(registerToHub, 10000);
  }
}

// 하트비트 전송
async function startHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
  }
  
  const axios = require('axios');
  const HUB_URL = process.env.HUB_URL;
  
  if (!HUB_URL || !registeredAgentId) return;
  
  // 즉시 첫 번째 하트비트 전송
  sendHeartbeat();
  
  // 10초마다 하트비트 전송
  heartbeatInterval = setInterval(sendHeartbeat, 10000);
}

async function sendHeartbeat() {
  const axios = require('axios');
  const HUB_URL = process.env.HUB_URL;
  
  if (!HUB_URL || !registeredAgentId) return;
  
  try {
    const response = await axios.post(`${HUB_URL}/api/agent/heartbeat/${registeredAgentId}`, {
      status: browser ? 'ready' : 'disconnected',
      memoryUsage: process.memoryUsage(),
      uptime: process.uptime()
    }, {
      headers: {
        'X-API-Key': HUB_SECRET,
        'Content-Type': 'application/json'
      },
      httpsAgent: HUB_URL.startsWith('https') ? httpsAgent : undefined
    });
    
    if (response.data && response.data.success) {
      // 하트비트 성공은 디버그 레벨로만 로깅 (너무 자주 발생)
      if (process.env.LOG_LEVEL === 'debug') {
        console.log(`Heartbeat sent successfully for agent ${registeredAgentId}`);
      }
    }
  } catch (error) {
    console.error('Failed to send heartbeat:', error.message);
    
    // 하트비트 실패가 계속되면 재등록 시도
    if (error.response && error.response.status === 404) {
      console.log('Agent not found in hub, attempting re-registration...');
      registeredAgentId = null;
      clearInterval(heartbeatInterval);
      registerToHub();
    }
  }
}

// Graceful shutdown 처리
async function gracefulShutdown(signal) {
  console.log(`Agent ${AGENT_ID} received ${signal}, shutting down gracefully...`);
  
  // 하트비트 중지
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
  }
  
  // 브라우저 종료
  if (browser) {
    try {
      await browser.close();
      console.log('Browser closed successfully');
    } catch (error) {
      console.error('Error closing browser:', error.message);
    }
  }
  
  // MCP 서버 종료
  try {
    await mcpIntegration.shutdown();
  } catch (error) {
    console.error('Error shutting down MCP:', error.message);
  }
  
  process.exit(0);
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

start().catch(console.error);