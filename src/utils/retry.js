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
      
      // 마지막 시도이거나 재시도하지 않아야 하는 에러인 경우
      if (attempt === maxAttempts || !shouldRetry(error)) {
        throw error;
      }
      
      // 재시도 콜백 실행
      onRetry(error, attempt);
      
      // 지수 백오프로 대기
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

// HTTP 상태 코드가 재시도 가능한지 확인
function isRetryableStatusCode(statusCode) {
  return statusCode === 408 || // Request Timeout
         statusCode === 429 || // Too Many Requests
         statusCode === 502 || // Bad Gateway
         statusCode === 503 || // Service Unavailable
         statusCode === 504;   // Gateway Timeout
}

module.exports = {
  withRetry,
  isNetworkError,
  isRetryableStatusCode
};