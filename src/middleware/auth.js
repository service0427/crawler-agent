const authenticateHub = (req, res, next) => {
  // 공개 경로는 인증 없이 허용
  const publicPaths = ['/health', '/metrics', '/'];
  if (publicPaths.includes(req.path)) {
    return next();
  }
  
  const hubAuth = req.headers['x-hub-auth'] || req.headers['x-api-key'];
  const clientIP = req.ip || req.connection.remoteAddress;
  
  // 시크릿 키 검증
  if (!hubAuth || hubAuth !== process.env.HUB_SECRET) {
    console.log(`[AUTH] Unauthorized request from ${clientIP}`);
    return res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid or missing API key'
    });
  }
  
  // IP 화이트리스트 검증 (프로덕션 환경에서만)
  if (process.env.NODE_ENV === 'production' && process.env.ALLOWED_HUB_IPS) {
    const allowedIPs = process.env.ALLOWED_HUB_IPS.split(',');
    const clientHost = req.hostname || clientIP;
    
    const isAllowed = allowedIPs.some(allowedIP => 
      clientHost === allowedIP || 
      clientIP === allowedIP || 
      clientIP.includes(allowedIP) || 
      allowedIP.includes(clientIP)
    );
    
    if (!isAllowed) {
      console.log(`[AUTH] Request from non-whitelisted IP: ${clientIP}`);
      return res.status(403).json({ 
        error: 'Forbidden',
        message: 'IP not allowed'
      });
    }
  }
  
  // 인증 성공
  console.log(`[AUTH] Authenticated request from ${clientIP}`);
  next();
};

module.exports = { authenticateHub };