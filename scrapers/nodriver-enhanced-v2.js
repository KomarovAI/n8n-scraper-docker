// 🚀 NODRIVER ENHANCED V2 - PRODUCTION READY
// Все критичные улучшения 2025: cleanup, instance limit, retry, GUI mode

const uc = require('nodriver'); // Assuming nodriver is available
const { 
  randomDelay, 
  retryWithBackoff,
  checkIfDetected 
} = require('../utils/anti-detection');

// Semaphore для ограничения concurrent instances (max 5)
class Semaphore {
  constructor(max) {
    this.max = max;
    this.current = 0;
    this.queue = [];
  }

  async acquire() {
    if (this.current < this.max) {
      this.current++;
      return;
    }
    await new Promise(resolve => this.queue.push(resolve));
  }

  release() {
    this.current--;
    if (this.queue.length > 0) {
      const resolve = this.queue.shift();
      this.current++;
      resolve();
    }
  }
}

const browserSemaphore = new Semaphore(5); // MAX 5 concurrent instances

/**
 * Enhanced Nodriver Scraper with Production Fixes
 * @param {Array<string>} urls - URLs для скрапинга
 * @param {Object} options - Опции
 * @returns {Promise<Object>} - Результаты
 */
async function nodriverEnhancedScraper(urls, options = {}) {
  const {
    concurrency = 8,
    timeout = 30000,
    headless = false, // FIX: GUI mode для лучшего bypass
    humanBehavior = true,
    delays = { min: 5000, max: 15000 }
  } = options;

  const results = {
    successful: [],
    failed: [],
    stats: {
      total: urls.length,
      successful: 0,
      failed: 0,
      detected: 0,
      avgProcessingTime: 0,
      instancesUsed: 0
    }
  };

  const activeBrowsers = new Set();

  // Cleanup helper
  async function cleanupBrowser(browser) {
    try {
      console.log('🧹 Cleaning up browser instance...');
      
      // Закрываем все вкладки
      if (browser.targets) {
        for (const target of browser.targets) {
          try {
            await target.close();
          } catch (e) {
            // ignore
          }
        }
      }
      
      // Останавливаем браузер
      await browser.stop();
      
      // Удаляем из активных
      activeBrowsers.delete(browser);
      
      console.log('✅ Browser cleanup complete');
    } catch (error) {
      console.error('⚠️ Cleanup error:', error.message);
    }
  }

  // Обработка батчами
  for (let i = 0; i < urls.length; i += concurrency) {
    const batch = urls.slice(i, i + concurrency);
    
    const batchPromises = batch.map(async (url) => {
      const startTime = Date.now();
      let browser = null;
      
      try {
        // FIX #1: Acquire semaphore (max 5 instances)
        await browserSemaphore.acquire();
        results.stats.instancesUsed++;

        // FIX #2: Retry with exponential backoff
        const scrapeWithRetry = async () => {
          // Запускаем браузер
          browser = await uc.start({
            headless: headless, // FIX: GUI mode по умолчанию
            browser_args: [
              '--no-sandbox',
              '--disable-setuid-sandbox',
              '--disable-dev-shm-usage',
              '--disable-blink-features=AutomationControlled'
            ]
          });

          activeBrowsers.add(browser);

          // FIX #3: Human-like delay перед навигацией
          if (humanBehavior && i > 0) {
            await randomDelay(delays.min, delays.max);
          }

          // Создаём вкладку
          const page = await browser.get(url);
          
          // Ждём загрузки
          await page.wait(timeout / 1000); // nodriver использует секунды

          // FIX #4: Проверка детекта
          const detection = await checkIfDetected(page);
          if (detection.hasCaptcha || detection.isBlocked || detection.hasCloudflare) {
            results.stats.detected++;
            console.warn(`⚠️ Detected on ${url}:`, detection);
          }

          // Получаем контент
          const html = await page.get_content();
          const title = await page.title;

          const processingTime = Date.now() - startTime;
          results.stats.avgProcessingTime += processingTime;

          return {
            url,
            html,
            title,
            processingTime,
            detection,
            timestamp: new Date().toISOString()
          };
        };

        // Retry logic
        const result = await retryWithBackoff(scrapeWithRetry, 3, 2000);
        
        results.successful.push(result);
        results.stats.successful++;

      } catch (error) {
        results.failed.push({
          url,
          error: error.message,
          timestamp: new Date().toISOString()
        });
        results.stats.failed++;
      } finally {
        // FIX #5: КРИТИЧНО - cleanup после каждого использования
        if (browser) {
          await cleanupBrowser(browser);
        }
        
        // Release semaphore
        browserSemaphore.release();
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

  // Финальная очистка (на всякий случай)
  for (const browser of activeBrowsers) {
    await cleanupBrowser(browser);
  }

  console.log(`📊 Nodriver Enhanced Stats:
    Total: ${results.stats.total}
    Successful: ${results.stats.successful}
    Failed: ${results.stats.failed}
    Detected: ${results.stats.detected}
    Instances Used: ${results.stats.instancesUsed}
    Avg Processing Time: ${results.stats.avgProcessingTime}ms
  `);

  return results;
}

module.exports = { nodriverEnhancedScraper };
