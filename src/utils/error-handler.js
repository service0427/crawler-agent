const fs = require('fs');
const path = require('path');

class ErrorHandler {
  constructor() {
    this.logDir = process.env.LOG_DIR || './logs';
    this.ensureLogDir();
  }
  
  ensureLogDir() {
    if (!fs.existsSync(this.logDir)) {
      fs.mkdirSync(this.logDir, { recursive: true });
    }
  }
  
  logError(error, context = {}) {
    const timestamp = new Date().toISOString();
    const errorLog = {
      timestamp,
      message: error.message,
      stack: error.stack,
      context,
      agentId: process.env.AGENT_ID,
      port: process.env.PORT
    };
    
    // 콘솔 출력
    console.error(`[ERROR] ${timestamp}:`, error.message);
    if (process.env.NODE_ENV === 'development') {
      console.error(error.stack);
    }
    
    // 파일 로깅
    const logFile = path.join(this.logDir, `error-${new Date().toISOString().split('T')[0]}.log`);
    fs.appendFileSync(logFile, JSON.stringify(errorLog) + '\n');
  }
  
  setupProcessHandlers() {
    // 처리되지 않은 예외
    process.on('uncaughtException', (error) => {
      this.logError(error, { type: 'uncaughtException' });
      // 안전한 종료 시도
      setTimeout(() => {
        process.exit(1);
      }, 1000);
    });
    
    // 처리되지 않은 Promise 거부
    process.on('unhandledRejection', (reason, promise) => {
      this.logError(new Error(reason), { 
        type: 'unhandledRejection',
        promise: promise.toString()
      });
    });
  }
  
  // Express 에러 핸들러 미들웨어
  expressErrorHandler() {
    return (err, req, res, next) => {
      this.logError(err, {
        method: req.method,
        path: req.path,
        ip: req.ip,
        headers: req.headers
      });
      
      res.status(err.status || 500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
        requestId: Date.now().toString(36)
      });
    };
  }
}

module.exports = ErrorHandler;