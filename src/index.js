require('dotenv').config();
const { chromium } = require('playwright');
const express = require('express');
const path = require('path');
const fs = require('fs');
const os = require('os');
const axios = require('axios');
const https = require('https');

// 개선된 유틸리티 모듈
const { authenticateHub } = require('./middleware/auth');
const ErrorHandler = require('./utils/error-handler');
const MemoryManager = require('./utils/memory-manager');
const Logger = require('./utils/logger');
const { withRetry, isNetworkError, isRetryableStatusCode } = require('./utils/retry');
const mcpIntegration = require('./mcp/mcp-integration');

// 환경 변수
const PORT = process.env.PORT || process.argv[2] || 3001;
const AGENT_ID = process.env.AGENT_ID || 'agent-1';
const HUB_SECRET = process.env.HUB_SECRET || 'your-hub-secret-key';
const HUB_URL = process.env.HUB_URL;
const ALLOWED_HUB_IPS = process.env.ALLOWED_HUB_IPS ? process.env.ALLOWED_HUB_IPS.split(',') : ['localhost', '127.0.0.1'];

// 전역 객체 초기화
const logger = new Logger();
const errorHandler = new ErrorHandler();
const memoryManager = new MemoryManager();

let browser;
let context;
let heartbeatInterval;
let registeredAgentId;

// Express 서버 설정
const app = express();
app.use(express.json({ 
  type: ['application/json', 'text/plain'], 
  limit: '10mb' 
}));

// 요청 로깅 미들웨어
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    headers: req.headers
  });
  next();
});

// 브라우저 초기화 (개선된 버전)
async function initBrowser() {
  try {
    const userDataDir = path.join(process.env.USER_DATA_DIR || './data/users', `user_${PORT}`);
    
    // 사용자 데이터 디렉토리 생성
    if (!fs.existsSync(userDataDir)) {
      fs.mkdirSync(userDataDir, { recursive: true });
    }
    
    const cdpPort = parseInt(PORT) + 1000;
    
    // 브라우저 실행 인수 (보안 강화)
    const args = [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-blink-features=AutomationControlled',
      '--disable-features=AutomationControlled',
      `--remote-debugging-port=${cdpPort}`,
      '--remote-debugging-address=127.0.0.1', // CDP를 localhost로 제한
      '--disable-web-security', // 개발용
      '--disable-features=IsolateOrigins,site-per-process',
      '--flag-switches-begin',
      '--disable-site-isolation-trials',
      '--flag-switches-end'
    ];
    
    // Playwright 브라우저 시작
    browser = await chromium.launch({
      headless: process.env.HEADLESS === 'true',
      channel: 'chrome',
      args: args,
      ignoreDefaultArgs: ['--enable-automation']
    });
    
    // 기본 컨텍스트 생성
    context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1280, height: 720 },
      locale: 'ko-KR',
      timezoneId: 'Asia/Seoul'
    });
    
    // 메모리 매니저에 컨텍스트 등록
    memoryManager.registerContext('default', context);
    
    logger.info('Browser initialized successfully', { cdpPort });
    return true;
    
  } catch (error) {
    logger.error('Failed to initialize browser', { error: error.message });
    return false;
  }
}

// API 라우트들

// 헬스 체크 (인증 불필요)
app.get('/health', (req, res) => {
  const memStats = memoryManager.getMemoryStats();
  res.json({
    success: true,
    agentId: AGENT_ID,
    port: PORT,
    cdpPort: parseInt(PORT) + 1000,
    status: browser ? 'ready' : 'disconnected',
    memory: memStats,
    uptime: process.uptime()
  });
});

// 메트릭스 엔드포인트 (모니터링용)
app.get('/metrics', (req, res) => {
  const metrics = {
    agent_id: AGENT_ID,
    port: PORT,
    status: browser ? 1 : 0,
    memory: memoryManager.getMemoryStats(),
    uptime: process.uptime(),
    timestamp: Date.now()
  };
  res.json(metrics);
});

// 메인 페이지
app.get('/', (req, res) => {
  res.json({
    success: true,
    agent: {
      id: AGENT_ID,
      port: PORT,
      cdpPort: parseInt(PORT) + 1000,
      status: browser ? 'ready' : 'disconnected'
    },
    workflows: getAvailableWorkflows()
  });
});

// 재시작 (인증 필요)
app.post('/restart', authenticateHub, async (req, res) => {
  try {
    logger.info('Restart requested');
    
    if (browser) {
      await browser.close();
    }
    
    const browserReady = await initBrowser();
    
    res.json({
      success: browserReady,
      message: browserReady ? 'Browser restarted' : 'Failed to restart browser'
    });
    
  } catch (error) {
    logger.error('Restart failed', { error: error.message });
    res.status(500).json({
      error: 'Restart failed',
      message: error.message
    });
  }
});

// 페이지 네비게이션 (인증 필요)
app.post('/navigate', authenticateHub, async (req, res) => {
  try {
    const { url, waitUntil = 'load' } = req.body;
    
    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }
    
    if (!browser) {
      return res.status(503).json({ error: 'Browser not initialized' });
    }
    
    logger.info('Navigating to URL', { url, waitUntil });
    
    const page = await context.newPage();
    
    // 재시도 로직 적용
    await withRetry(
      async () => {
        await page.goto(url, { 
          waitUntil: waitUntil,
          timeout: 30000 
        });
      },
      {
        maxAttempts: 3,
        shouldRetry: (error) => isNetworkError(error),
        onRetry: (error, attempt) => {
          logger.warn(`Navigation retry ${attempt}`, { url, error: error.message });
        }
      }
    );
    
    const title = await page.title();
    
    res.json({
      success: true,
      title: title,
      url: page.url()
    });
    
    // 메모리 사용량 업데이트
    memoryManager.updateContextUsage('default');
    
  } catch (error) {
    logger.error('Navigation failed', { error: error.message });
    res.status(500).json({
      error: 'Navigation failed',
      message: error.message
    });
  }
});

// 워크플로우 실행 (인증 필요)
app.post('/workflow', authenticateHub, async (req, res) => {
  try {
    const { workflowName, params = {} } = req.body;
    
    if (!workflowName) {
      return res.status(400).json({ error: 'Workflow name is required' });
    }
    
    if (!browser) {
      return res.status(503).json({ error: 'Browser not initialized' });
    }
    
    logger.info('Executing workflow', { workflowName, params });
    
    // 워크플로우 파일 로드
    const workflowPath = path.join(__dirname, 'workflows', `${workflowName}.js`);
    
    if (!fs.existsSync(workflowPath)) {
      return res.status(404).json({ error: 'Workflow not found' });
    }
    
    const workflow = require(workflowPath);
    const page = await context.newPage();
    
    // 타임아웃 설정
    const timeout = params.timeout || 120000; // 기본 2분
    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Workflow timeout')), timeout)
    );
    
    // 워크플로우 실행
    const result = await Promise.race([
      workflow.execute(page, params),
      timeoutPromise
    ]);
    
    await page.close();
    
    res.json({
      success: true,
      workflowName: workflowName,
      result: result
    });
    
    // 메모리 사용량 업데이트
    memoryManager.updateContextUsage('default');
    
  } catch (error) {
    logger.error('Workflow execution failed', { 
      workflowName: req.body.workflowName,
      error: error.message 
    });
    
    res.status(500).json({
      success: false,
      error: 'Workflow execution failed',
      message: error.message
    });
  }
});

// 사용 가능한 워크플로우 목록
app.get('/workflows', (req, res) => {
  res.json({
    success: true,
    workflows: getAvailableWorkflows()
  });
});

// 워크플로우 목록 가져오기
function getAvailableWorkflows() {
  const workflowDir = path.join(__dirname, 'workflows');
  
  if (!fs.existsSync(workflowDir)) {
    return [];
  }
  
  return fs.readdirSync(workflowDir)
    .filter(file => file.endsWith('.js'))
    .map(file => file.replace('.js', ''));
}

// 허브 등록 (재시도 로직 포함)
async function registerToHub() {
  try {
    if (!HUB_URL) {
      logger.warn('HUB_URL not configured');
      return;
    }
    
    const localIP = getLocalIP();
    const workflows = getAvailableWorkflows();
    
    logger.info('Registering to hub', { hubUrl: HUB_URL, localIP });
    
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
          httpsAgent: new https.Agent({
            rejectUnauthorized: false
          })
        });
      },
      {
        maxAttempts: 5,
        delay: 2000,
        shouldRetry: (error) => {
          if (error.response) {
            return isRetryableStatusCode(error.response.status);
          }
          return isNetworkError(error);
        },
        onRetry: (error, attempt) => {
          logger.warn(`Hub registration retry ${attempt}`, { 
            error: error.message,
            status: error.response?.status 
          });
        }
      }
    );
    
    registeredAgentId = response.data.id || AGENT_ID;
    logger.info('Successfully registered to hub', { agentId: registeredAgentId });
    
    // 하트비트 시작
    startHeartbeat();
    
  } catch (error) {
    logger.error('Failed to register to hub', { 
      error: error.message,
      status: error.response?.status 
    });
    
    // 10초 후 재시도
    setTimeout(registerToHub, 10000);
  }
}

// 하트비트 전송
async function sendHeartbeat() {
  try {
    const memStats = memoryManager.getMemoryStats();
    
    await axios.post(
      `${HUB_URL}/api/agent/heartbeat/${registeredAgentId}`,
      {
        status: browser ? 'ready' : 'disconnected',
        memory: memStats,
        uptime: process.uptime()
      },
      {
        headers: {
          'X-API-Key': HUB_SECRET,
          'Content-Type': 'application/json'
        },
        httpsAgent: new https.Agent({
          rejectUnauthorized: false
        })
      }
    );
    
    logger.debug('Heartbeat sent', { agentId: registeredAgentId });
    
  } catch (error) {
    logger.warn('Heartbeat failed', { 
      error: error.message,
      status: error.response?.status 
    });
    
    // 404 에러 시 재등록
    if (error.response && error.response.status === 404) {
      logger.info('Agent not found in hub, re-registering...');
      clearInterval(heartbeatInterval);
      await registerToHub();
    }
  }
}

// 하트비트 시작
function startHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
  }
  
  const interval = parseInt(process.env.HEARTBEAT_INTERVAL) || 10000;
  heartbeatInterval = setInterval(sendHeartbeat, interval);
  logger.info('Heartbeat started', { interval });
}

// 로컬 IP 가져오기
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

// 메인 시작 함수
async function start() {
  // 에러 핸들러 설정
  errorHandler.setupProcessHandlers();
  
  logger.info('Starting agent', { 
    agentId: AGENT_ID,
    port: PORT,
    nodeEnv: process.env.NODE_ENV 
  });
  
  // 브라우저 초기화
  const browserReady = await initBrowser();
  
  if (browserReady) {
    // MCP 통합 초기화
    await mcpIntegration.initialize(context);
    
    // Express 서버 시작
    const BIND_ADDRESS = process.env.BIND_ADDRESS || '0.0.0.0';
    
    const server = app.listen(PORT, BIND_ADDRESS, () => {
      logger.info('HTTP server ready', { 
        address: BIND_ADDRESS,
        port: PORT 
      });
      
      // 허브에 등록
      registerToHub();
    });
    
    // Express 에러 핸들러 추가
    app.use(errorHandler.expressErrorHandler());
    
    // Graceful shutdown 설정
    const gracefulShutdown = async () => {
      logger.info('Graceful shutdown initiated');
      
      if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
      }
      
      memoryManager.stopMonitoring();
      
      if (browser) {
        await browser.close();
      }
      
      await mcpIntegration.shutdown();
      
      server.close(() => {
        logger.info('Server closed');
        process.exit(0);
      });
    };
    
    process.on('SIGINT', gracefulShutdown);
    process.on('SIGTERM', gracefulShutdown);
    
  } else {
    logger.error('Failed to start browser, exiting...');
    process.exit(1);
  }
}

// 애플리케이션 시작
start().catch((error) => {
  logger.error('Fatal error during startup', { error: error.message });
  console.error(error);
  process.exit(1);
});