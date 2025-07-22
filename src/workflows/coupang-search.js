/**
 * 쿠팡 상품 검색 워크플로우 (페이지네이션 지원)
 * 키워드로 검색하여 상품 목록 추출
 */
const { createLogger } = require('./logger');

module.exports = {
  name: 'coupang-search',
  description: '쿠팡에서 상품 검색 및 데이터 추출',
  
  async execute(page, params) {
    const { keyword, limit = null } = params;
    const log = createLogger('[coupang-search]');
    
    if (!keyword) {
      throw new Error('Keyword is required');
    }
    
    log.separator();
    log.info(`Starting search for: ${keyword}, limit: ${limit || '제한없음'}`);
    
    // 페이지당 최대 72개, 광고 제외하면 실제로는 더 적을 수 있음
    const pageSize = 72;
    let allProducts = [];
    let currentPage = 1;
    let shouldContinue = true;
    let relatedKeywords = []; // 연관 검색어
    
    // 네트워크 응답 모니터링 설정
    let networkBlocked = false;
    let failedRequests = [];
    
    const requestFailedHandler = (request) => {
      const url = request.url();
      const failure = request.failure();
      if (url.includes('coupang.com')) {
        log.warn(`Request failed: ${url}`);
        log.warn(`Failure reason: ${failure?.errorText}`);
        failedRequests.push({
          url: url,
          error: failure?.errorText
        });
        if (failure?.errorText === 'net::ERR_BLOCKED_BY_CLIENT' || 
            failure?.errorText === 'net::ERR_FAILED' ||
            failure?.errorText === 'net::ERR_HTTP2_PROTOCOL_ERROR' ||
            failure?.errorText === 'net::ERR_CONNECTION_REFUSED' ||
            failure?.errorText === 'net::ERR_CONNECTION_RESET') {
          networkBlocked = true;
        }
      }
    };
    
    page.on('requestfailed', requestFailedHandler);
    
    try {
      while (shouldContinue) {
        log.log(`\n페이지 ${currentPage} 크롤링 시작...`);
        
        // 검색 URL 생성
        const searchUrl = `https://www.coupang.com/np/search?q=${encodeURIComponent(keyword)}&channel=user&failRedirectApp=true&page=${currentPage}&listSize=${pageSize}`;
        log.log(`Navigating to: ${searchUrl}`);
        
        // 페이지 이동
        let response;
        try {
          response = await page.goto(searchUrl, { 
            waitUntil: 'domcontentloaded',
            timeout: 30000
          });
        } catch (error) {
          log.error(`Navigation failed: ${error.message}`);
          return {
            keyword: keyword,
            count: allProducts.length,
            products: allProducts,
            searchUrl: searchUrl,
            blocked: true,
            message: '네트워크 레벨 차단 (Navigation failed)',
            error: error.message,
            failedRequests: failedRequests,
            timestamp: new Date().toISOString()
          };
        }
        
        const status = response ? response.status() : 0;
        const currentUrl = page.url();
        log.log(`Response status: ${status}`);
        log.log(`Current URL: ${currentUrl}`);

        // chrome-error URL은 네트워크 차단을 의미
        if (currentUrl.startsWith('chrome-error://') || networkBlocked) {
          log.error(`네트워크 레벨 차단 감지됨!`);
          log.error(`차단된 URL: ${currentUrl}`);
          if (failedRequests.length > 0) {
            log.error(`실패한 요청들:`, failedRequests);
          }
          return {
            keyword: keyword,
            count: allProducts.length,
            products: allProducts,
            searchUrl: currentUrl,
            blocked: true,
            message: '네트워크 레벨에서 차단됨',
            networkBlocked: true,
            failedRequests: failedRequests,
            timestamp: new Date().toISOString()
          };
        }
        
        // 페이지 초기 로드 대기
        await new Promise(resolve => setTimeout(resolve, 500));
        
        // "검색결과가 없습니다" 체크
        const quickCheck = await page.evaluate(() => {
          const noResultElement = document.querySelector('[class^=no-result_magnifier]');
          const noResultText = document.body?.innerText?.includes('에 대한 검색결과가 없습니다');
          const hasProductList = !!document.querySelector('#product-list');
          
          return {
            hasNoResult: !!noResultElement || !!noResultText,
            hasProductList: hasProductList
          };
        });
        
        if (quickCheck.hasNoResult && currentPage === 1) {
          log.warn(`검색 결과 없음 - "${keyword}"에 대한 검색결과가 없습니다.`);
          return {
            keyword: keyword,
            count: 0,
            products: [],
            searchUrl: page.url(),
            message: `"${keyword}"에 대한 검색결과가 없습니다`,
            noResults: true,
            timestamp: new Date().toISOString()
          };
        }
        
        // 상품 리스트 대기
        if (!quickCheck.hasProductList) {
          try {
            await page.waitForSelector('#product-list', { timeout: 5000 });
          } catch (error) {
            log.warn(`페이지 ${currentPage}: 상품 리스트를 찾을 수 없음`);
            break;
          }
        }
        
        // 상품 데이터 추출
        const pageProducts = await page.evaluate((maxItems) => {
          const items = document.querySelectorAll('#product-list > li[data-id]');
          
          const filteredItems = Array.from(items)
            .filter(i => {
              // 광고 상품 제외
              const linkElement = i.querySelector('a');
              const adMarkElement = i.querySelector('[class*=AdMark]');
              const href = linkElement ? linkElement.getAttribute('href') : '';
              return !adMarkElement && !href.includes('sourceType=srp_product_ads');
            });
          
          return filteredItems.map(i => {
            const linkElement = i.querySelector('a');
            const imgElement = i.querySelector('img');
            const href = linkElement ? linkElement.getAttribute('href') : '';
            
            // URL에서 rank 추출
            let rank = null;
            let productId = null;
            let itemId = null;
            let vendorItemId = null;
            
            if (href) {
              const rankMatch = href.match(/rank=(\d+)/);
              rank = rankMatch ? rankMatch[1] : null;
              
              // 상품 ID 추출 (URL 경로에서)
              const productIdMatch = href.match(/\/vp\/products\/(\d+)/);
              productId = productIdMatch ? productIdMatch[1] : null;
              
              // itemId 추출
              const itemIdMatch = href.match(/itemId=(\d+)/);
              itemId = itemIdMatch ? itemIdMatch[1] : null;
              
              // vendorItemId 추출
              const vendorItemIdMatch = href.match(/vendorItemId=(\d+)/);
              vendorItemId = vendorItemIdMatch ? vendorItemIdMatch[1] : null;
            }
            
            return {
              id: i.dataset.id,
              name: i.querySelector('[class*=productName]')?.innerText,
              href: linkElement ? 'https://www.coupang.com' + href : null,
              thumbnail: imgElement ? imgElement.getAttribute('src') : null,
              rank: rank,
              productId: productId,
              itemId: itemId,
              vendorItemId: vendorItemId,
              realRank: null, // 실제 순위는 외부에서 설정
              page: null // 페이지 번호는 외부에서 설정
            };
          });
        });
        
        // 페이지 번호 및 실제 순위 추가
        pageProducts.forEach((product, index) => {
          product.page = currentPage;
          // realRank 계산: 전체 상품 목록에서의 실제 순서
          product.realRank = allProducts.length + index + 1;
        });
        
        log.log(`페이지 ${currentPage}: ${pageProducts.length}개 상품 추출됨`);
        
        // 1페이지에서만 연관 검색어 추출
        if (currentPage === 1) {
          log.log('연관 검색어 추출 시도 중...');
          try {
            // 연관 검색어 영역이 로드될 때까지 잠시 대기
            await page.waitForTimeout(1000);
            
            // 연관 검색어 추출
            relatedKeywords = await page.evaluate(() => {
              return Array.from(document.querySelectorAll('[class^="srp_relatedKeywords"] a'))
                .map(a => a.textContent.trim())
                .filter(keyword => keyword.length > 0);
            });
            
            if (relatedKeywords.length > 0) {
              log.log(`연관 검색어 ${relatedKeywords.length}개 추출됨: ${relatedKeywords.slice(0, 5).join(', ')}${relatedKeywords.length > 5 ? ' ...' : ''}`);
            } else {
              log.log('연관 검색어를 찾을 수 없음');
            }
          } catch (error) {
            log.warn('연관 검색어 추출 실패:', error.message);
          }
        }
        
        // 전체 상품 목록에 추가
        allProducts = allProducts.concat(pageProducts);
        
        // 마지막 상품의 순위 확인
        let lastRank = 0;
        if (pageProducts.length > 0) {
          const lastProduct = pageProducts[pageProducts.length - 1];
          if (lastProduct.rank) {
            lastRank = parseInt(lastProduct.rank);
          }
        }
        
        // 종료 조건 체크
        if (limit && allProducts.length >= limit) {
          // limit에 도달하면 필요한 만큼만 잘라내고 종료
          allProducts = allProducts.slice(0, limit);
          shouldContinue = false;
        } else if (pageProducts.length === 0) {
          // 더 이상 상품이 없으면 종료
          log.log(`페이지 ${currentPage}: 더 이상 상품이 없습니다.`);
          shouldContinue = false;
        } else if (!limit && lastRank >= 300) {
          // 순위 300위 이상이면 종료
          log.log(`순위 ${lastRank}위에 도달하여 크롤링을 종료합니다.`);
          shouldContinue = false;
        } else if (!limit && currentPage >= 5) {
          // limit이 없어도 최대 5페이지까지만
          log.log(`최대 페이지 수(5)에 도달했습니다.`);
          shouldContinue = false;
        } else {
          // 다음 페이지로
          currentPage++;
          await new Promise(resolve => setTimeout(resolve, 500)); // 페이지 간 대기 단축
        }
      }
      
    } finally {
      // 이벤트 리스너 제거
      page.off('requestfailed', requestFailedHandler);
    }
    
    log.success(`총 ${allProducts.length}개 상품 추출 완료`);
    log.separator();
    
    // 작업 완료 후 about:blank로 이동
    try {
      await page.goto('about:blank', { waitUntil: 'domcontentloaded' });
      log.info('Navigated to about:blank');
    } catch (error) {
      log.warn(`Failed to navigate to about:blank: ${error.message}`);
    }

    return {
      keyword: keyword,
      count: allProducts.length,
      products: allProducts,
      relatedKeywords: relatedKeywords,
      totalPages: currentPage,
      searchUrl: `https://www.coupang.com/np/search?q=${encodeURIComponent(keyword)}`,
      timestamp: new Date().toISOString()
    };
  }
};