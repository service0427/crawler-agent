class MemoryManager {
  constructor() {
    this.memoryThreshold = parseInt(process.env.MEMORY_THRESHOLD) || 1024 * 1024 * 1024; // 1GB
    this.checkInterval = parseInt(process.env.MEMORY_CHECK_INTERVAL) || 60000; // 1분
    this.contexts = new Map();
    this.startMonitoring();
  }
  
  startMonitoring() {
    this.monitoringInterval = setInterval(() => {
      this.checkMemory();
    }, this.checkInterval);
  }
  
  stopMonitoring() {
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
    }
  }
  
  checkMemory() {
    const memUsage = process.memoryUsage();
    const heapUsedMB = Math.round(memUsage.heapUsed / 1024 / 1024);
    const heapTotalMB = Math.round(memUsage.heapTotal / 1024 / 1024);
    const rssMB = Math.round(memUsage.rss / 1024 / 1024);
    
    console.log(`[MEMORY] Heap: ${heapUsedMB}/${heapTotalMB}MB, RSS: ${rssMB}MB`);
    
    // 메모리 임계값 초과 시
    if (memUsage.heapUsed > this.memoryThreshold) {
      console.warn(`[MEMORY] Warning: Memory usage (${heapUsedMB}MB) exceeds threshold`);
      this.cleanup();
    }
    
    return {
      heapUsed: heapUsedMB,
      heapTotal: heapTotalMB,
      rss: rssMB,
      external: Math.round(memUsage.external / 1024 / 1024)
    };
  }
  
  async cleanup() {
    console.log('[MEMORY] Starting cleanup...');
    
    // 가비지 컬렉션 강제 실행 (--expose-gc 플래그 필요)
    if (global.gc) {
      global.gc();
      console.log('[MEMORY] Garbage collection triggered');
    }
    
    // 오래된 컨텍스트 정리
    const now = Date.now();
    for (const [id, context] of this.contexts.entries()) {
      if (now - context.lastUsed > 300000) { // 5분 이상 미사용
        try {
          await context.close();
          this.contexts.delete(id);
          console.log(`[MEMORY] Closed idle context: ${id}`);
        } catch (error) {
          console.error(`[MEMORY] Error closing context ${id}:`, error.message);
        }
      }
    }
  }
  
  registerContext(id, context) {
    this.contexts.set(id, {
      context,
      lastUsed: Date.now()
    });
  }
  
  updateContextUsage(id) {
    const ctx = this.contexts.get(id);
    if (ctx) {
      ctx.lastUsed = Date.now();
    }
  }
  
  getMemoryStats() {
    const stats = this.checkMemory();
    return {
      ...stats,
      contexts: this.contexts.size,
      uptime: Math.round(process.uptime()),
      threshold: Math.round(this.memoryThreshold / 1024 / 1024)
    };
  }
}

module.exports = MemoryManager;