const fs = require('fs');
const path = require('path');

class Logger {
  constructor(options = {}) {
    this.logDir = options.logDir || process.env.LOG_DIR || './logs';
    this.logLevel = options.logLevel || process.env.LOG_LEVEL || 'info';
    this.maxFileSize = options.maxFileSize || 10 * 1024 * 1024; // 10MB
    this.maxFiles = options.maxFiles || 5;
    
    this.levels = {
      error: 0,
      warn: 1,
      info: 2,
      debug: 3
    };
    
    this.ensureLogDir();
  }
  
  ensureLogDir() {
    if (!fs.existsSync(this.logDir)) {
      fs.mkdirSync(this.logDir, { recursive: true });
    }
  }
  
  shouldLog(level) {
    return this.levels[level] <= this.levels[this.logLevel];
  }
  
  formatLog(level, message, meta = {}) {
    return JSON.stringify({
      timestamp: new Date().toISOString(),
      level: level.toUpperCase(),
      agentId: process.env.AGENT_ID,
      port: process.env.PORT,
      message,
      ...meta
    });
  }
  
  writeLog(level, message, meta) {
    if (!this.shouldLog(level)) return;
    
    const logEntry = this.formatLog(level, message, meta);
    
    // 콘솔 출력
    const color = {
      error: '\x1b[31m',
      warn: '\x1b[33m',
      info: '\x1b[36m',
      debug: '\x1b[90m'
    }[level];
    
    console.log(`${color}[${level.toUpperCase()}]\x1b[0m ${message}`);
    
    // 파일 로깅
    const date = new Date().toISOString().split('T')[0];
    const logFile = path.join(this.logDir, `agent-${date}.log`);
    
    fs.appendFile(logFile, logEntry + '\n', (err) => {
      if (err) console.error('Failed to write log:', err);
    });
    
    // 로그 파일 로테이션 체크
    this.checkRotation(logFile);
  }
  
  checkRotation(logFile) {
    fs.stat(logFile, (err, stats) => {
      if (!err && stats.size > this.maxFileSize) {
        this.rotateLog(logFile);
      }
    });
  }
  
  rotateLog(logFile) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const rotatedFile = logFile.replace('.log', `-${timestamp}.log`);
    
    fs.rename(logFile, rotatedFile, (err) => {
      if (err) {
        console.error('Failed to rotate log:', err);
      } else {
        console.log(`Log rotated: ${rotatedFile}`);
        this.cleanOldLogs();
      }
    });
  }
  
  cleanOldLogs() {
    fs.readdir(this.logDir, (err, files) => {
      if (err) return;
      
      const logFiles = files
        .filter(f => f.endsWith('.log'))
        .map(f => ({
          name: f,
          path: path.join(this.logDir, f),
          time: fs.statSync(path.join(this.logDir, f)).mtime
        }))
        .sort((a, b) => b.time - a.time);
      
      // 오래된 로그 파일 삭제
      logFiles.slice(this.maxFiles).forEach(file => {
        fs.unlink(file.path, (err) => {
          if (!err) console.log(`Deleted old log: ${file.name}`);
        });
      });
    });
  }
  
  error(message, meta) {
    this.writeLog('error', message, meta);
  }
  
  warn(message, meta) {
    this.writeLog('warn', message, meta);
  }
  
  info(message, meta) {
    this.writeLog('info', message, meta);
  }
  
  debug(message, meta) {
    this.writeLog('debug', message, meta);
  }
}

module.exports = Logger;