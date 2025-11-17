// 🎭 PLAYWRIGHT STEALTH SCRAPER V3 - WITH ANTI-DETECTION
// Интегрированы anti-detection техники для обхода антибот-систем

const { chromium } = require('playwright');
const {
  randomDelay,
  smartDelay,
  getRandomUserAgent,
  getRandomViewport,
  humanLikeScroll,
  moveMouseRandomly,
  getStealthConfig,
  checkIfDetected,
  retryWithBackoff
} = require('../utils/anti-detection');

/**
 * Playwright Stealth Scraper with Anti-Detection
 * @param {Array<string>} urls - URLs для скрапинга
 * @param {Object} options - Опции
 * @returns {Promise<Object>} - Результаты скрапинга
 */
async function playwrightStealthScraper(urls, options = {}) {
  const {
    concurrency = 5,
    timeout = 30000,
    waitForSelector = null,
    antiDetection = {
      enabled: true,
      humanLikeScrolling: true,
      mouseMoves: true,
      delayBetweenRequests: { min: 3000, max: 7000 },
      randomizeOrder: false
    }
  } = options;

  const results = {
    successful: [],
    failed: [],
    stats: {
      total: urls.length,
      successful: 0,
      failed: 0,
      detected: 0,
      avgProcessingTime: 0
    }
  };

  let browser;
  
  try {
    // Получаем stealth конфигурацию
    const stealthConfig = antiDetection.enabled ? getStealthConfig() : {};
    
    // Запускаем браузер с stealth настройками
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-blink-features=AutomationControlled', // Скрываем automation
        '--disable-features=IsolateOrigins,site-per-process'
      ]
    });

    const context = await browser.newContext({
      ...stealthConfig,
      // Дополнительные stealth настройки
      javaScriptEnabled: true,
      ignoreHTTPSErrors: true
    });

    // Убираем webdriver флаг
    await context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', {
        get: () => false
      });
      
      // Добавляем chrome object
      window.chrome = {
        runtime: {}
      };
      
      // Переопределяем permissions API
      const originalQuery = window.navigator.permissions.query;
      window.navigator.permissions.query = (parameters) => (
        parameters.name === 'notifications' ?
          Promise.resolve({ state: Notification.permission }) :
          originalQuery(parameters)
      );
    });

    // Рандомизируем порядок URLs (опционально)
    const urlsToProcess = antiDetection.randomizeOrder ? 
      urls.sort(() => Math.random() - 0.5) : urls;

    // Обрабатываем URLs батчами
    for (let i = 0; i < urlsToProcess.length; i += concurrency) {
      const batch = urlsToProcess.slice(i, i + concurrency);
      
      const batchPromises = batch.map(async (url) => {
        const startTime = Date.now();
        const page = await context.newPage();
        
        try {
          // Задержка перед запросом
          if (antiDetection.enabled && i > 0) {
            const delay = antiDetection.delayBetweenRequests;
            await randomDelay(delay.min, delay.max);
          }

          // Переход на страницу
          await page.goto(url, {
            timeout,
            waitUntil: 'networkidle'
          });

          // Ждём конкретный selector (если указан)
          if (waitForSelector) {
            await page.waitForSelector(waitForSelector, { timeout: 5000 })
              .catch(() => console.log(`Selector ${waitForSelector} not found`));
          }

          // Anti-detection: human-like scrolling
          if (antiDetection.enabled && antiDetection.humanLikeScrolling) {
            await humanLikeScroll(page, {
              scrollSteps: Math.floor(Math.random() * 3) + 2, // 2-4 скролла
              scrollDelay: { min: 1000, max: 2500 }
            });
          }

          // Anti-detection: random mouse movements
          if (antiDetection.enabled && antiDetection.mouseMoves) {
            for (let m = 0; m < 3; m++) {
              await moveMouseRandomly(page);
            }
          }

          // Проверяем не были ли мы детектированы
          const detection = await checkIfDetected(page);
          if (detection.hasCaptcha || detection.isBlocked || detection.hasCloudflare) {
            results.stats.detected++;
            console.warn(`⚠️ Detected antibot on ${url}:`, detection);
          }

          // Получаем контент
          const html = await page.content();
          const title = await page.title();
          
          const processingTime = Date.now() - startTime;
          results.stats.avgProcessingTime += processingTime;

          results.successful.push({
            url,
            html,
            title,
            processingTime,
            detection,
            timestamp: new Date().toISOString()
          });
          
          results.stats.successful++;

        } catch (error) {
          results.failed.push({
            url,
            error: error.message,
            timestamp: new Date().toISOString()
          });
          results.stats.failed++;
        } finally {
          await page.close().catch(() => {});
        }
      });

      await Promise.all(batchPromises);
    }

    // Рассчитываем среднее время
    if (results.stats.successful > 0) {
      results.stats.avgProcessingTime = Math.floor(
        results.stats.avgProcessingTime / results.stats.successful
      );
    }

  } catch (error) {
    console.error('Browser launch failed:', error);
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }

  return results;
}

module.exports = { playwrightStealthScraper };
