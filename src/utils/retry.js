// 재시도 유틸리티 - 네트워크 요청 안정성 향상
async function withRetry(fn, options = {}) {
  const {
    maxAttempts = 3,
    delay = 1000,
    backoff = 2,
    shouldRetry = (error) => true,
    onRetry = (error, attempt) => {}
  } = options;
  
  let lastError;
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      
      if (attempt === maxAttempts || !shouldRetry(error)) {
        throw error;
      }
      
      onRetry(error, attempt);
      
      const waitTime = delay * Math.pow(backoff, attempt - 1);
      console.log(`[RETRY] Attempt ${attempt}/${maxAttempts} failed. Waiting ${waitTime}ms before retry...`);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
  }
  
  throw lastError;
}

// 네트워크 에러인지 확인
function isNetworkError(error) {
  return error.code === 'ECONNREFUSED' || 
         error.code === 'ENOTFOUND' || 
         error.code === 'ETIMEDOUT' ||
         error.code === 'ECONNRESET' ||
         error.message.includes('network');
}

module.exports = {
  withRetry,
  isNetworkError
};