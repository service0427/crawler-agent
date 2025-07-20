/**
 * 기본 데이터 추출 워크플로우
 * URL에서 특정 셀렉터의 데이터를 추출
 */
module.exports = {
  name: 'sample-extract',
  description: '페이지에서 데이터 추출하는 기본 워크플로우',
  
  async execute(page, params) {
    const { url, selectors } = params;
    
    if (!url) {
      throw new Error('URL is required');
    }
    
    // 페이지 이동
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    
    // 데이터 추출
    const data = await page.evaluate((selectors) => {
      const result = {};
      
      for (const [key, selector] of Object.entries(selectors || {})) {
        const element = document.querySelector(selector);
        if (element) {
          result[key] = element.textContent.trim();
        }
      }
      
      return result;
    }, selectors);
    
    return {
      url: page.url(),
      data: data,
      timestamp: new Date().toISOString()
    };
  }
};