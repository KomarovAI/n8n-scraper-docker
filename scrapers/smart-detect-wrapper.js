// 🧠 SMART DETECTION SCRAPER WRAPPER
// Автоматический выбор режима антидетекта: fast (без) → stealth (при block)

const { playwrightStealthScraper } = require('../scrapers/playwright-stealth-v3');

/**
 * Smart scraping: сначала fast, при детекте блоков — stealth
 * @param {string[]} urls — Массив URLs
 * @returns {Promise<Object[]>} Массив результатов
 */
async function smartScrapeBatch(urls) {
  const results = [];
  for (const url of urls) {
    // Быстрая попытка (без антидетекта)
    let run = await playwrightStealthScraper([url], {
      concurrency: 1,
      antiDetection: { enabled: false }
    });
    let out = run.successful && run.successful[0];

    // Проверка: был ли блок/детект/captcha или подозрительно мало текста
    const detection = out && out.detection;
    const isBlocked = detection && (detection.isBlocked || detection.hasCaptcha || detection.hasCloudflare);
    const tooShort = out && out.html && out.html.length < 1000; // length threshold (можно скорректировать)
    if (!out || isBlocked || tooShort) {
      // Повтор с антидетектом!
      run = await playwrightStealthScraper([url], {
        concurrency: 1,
        antiDetection: {
          enabled: true,
          humanLikeScrolling: true,
          mouseMoves: true,
          delayBetweenRequests: { min: 5000, max: 10000 },
          randomizeOrder: false
        }
      });
      out = run.successful && run.successful[0];
      out && (out.smartFallback = true);
    }
    results.push(out || { url, error: 'Failed after stealth fallback' });
  }
  return results;
}

module.exports = { smartScrapeBatch };
