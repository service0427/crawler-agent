/**
 * 테스트용 간단한 워크플로우
 * 디버깅과 개발 테스트를 위한 심플한 워크플로우
 */
const { createLogger } = require('./logger');

module.exports = {
  name: 'test-workflow',
  description: '간단한 테스트 워크플로우 - 페이지 정보 추출',
  
  async execute(page, params) {
    const { url = 'https://www.google.com', selector = 'body' } = params;
    const log = createLogger('[test-workflow]');
    
    log.separator();
    log.info(`Starting test workflow`);
    log.log(`URL: ${url}`);
    log.log(`Selector: ${selector}`);
    
    try {
      // 1단계: 페이지 이동
      log.log(` Step 1: Navigating to ${url}`);
      const response = await page.goto(url, { 
        waitUntil: 'domcontentloaded',
        timeout: 30000 
      });
      
      const status = response.status();
      log.log(` Navigation complete. Status: ${status}`);
      
      // 2단계: 대기
      log.log(` Step 2: Waiting 2 seconds...`);
      await new Promise(resolve => setTimeout(resolve, 2000));
      log.log(` Wait complete`);
      
      // 3단계: 페이지 정보 추출
      log.log(` Step 3: Extracting page info`);
      const pageInfo = await page.evaluate((sel) => {
        const element = document.querySelector(sel);
        return {
          title: document.title,
          url: window.location.href,
          elementFound: !!element,
          elementText: element ? element.innerText.substring(0, 100) : null,
          timestamp: new Date().toISOString()
        };
      }, selector);
      
      log.log(` Page info extracted:`, JSON.stringify(pageInfo, null, 2));
      
      // 4단계: 스크린샷 (선택사항)
      if (params.screenshot) {
        log.log(` Step 4: Taking screenshot`);
        const screenshotPath = `/tmp/test-workflow-${Date.now()}.png`;
        await page.screenshot({ path: screenshotPath });
        log.log(` Screenshot saved to: ${screenshotPath}`);
        pageInfo.screenshot = screenshotPath;
      }
      
      // 결과 반환
      log.success(`Workflow completed successfully`);
      log.separator();
      return {
        success: true,
        ...pageInfo,
        params: params
      };
      
    } catch (error) {
      log.error(` Error occurred:`, error.message);
      return {
        success: false,
        error: error.message,
        url: url,
        timestamp: new Date().toISOString()
      };
    }
  }
};