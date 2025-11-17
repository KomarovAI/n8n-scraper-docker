// 🕵️ ANTI-DETECTION UTILITIES
// Техники для незаметного скрапинга и обхода антибот-систем
// Использование: импортируй эти функции в scrapers для человекоподобного поведения

/**
 * 1. Random delays (случайные задержки)
 * Имитирует время реакции человека
 */
function randomDelay(min, max) {
  const delay = Math.floor(Math.random() * (max - min + 1)) + min;
  return new Promise(resolve => setTimeout(resolve, delay));
}

/**
 * 2. Smart delay (умная задержка)
 * Базовая задержка ± 50% для естественности
 */
async function smartDelay(baseDelay = 2000) {
  const min = Math.floor(baseDelay * 0.5);
  const max = Math.floor(baseDelay * 1.5);
  await randomDelay(min, max);
}

/**
 * 3. Random User-Agent
 * Ротация реальных User-Agents популярных браузеров
 */
function getRandomUserAgent() {
  const userAgents = [
    // Chrome на Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    
    // Chrome на macOS
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    
    // Firefox на Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
    
    // Firefox на Linux
    'Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0',
    
    // Edge на Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
    
    // Safari на macOS
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15'
  ];
  
  return userAgents[Math.floor(Math.random() * userAgents.length)];
}

/**
 * 4. Random viewport/screen resolution
 * Разные размеры экрана для каждой сессии
 */
function getRandomViewport() {
  const viewports = [
    { width: 1920, height: 1080 },  // Full HD
    { width: 1366, height: 768 },   // Популярный ноутбук
    { width: 1440, height: 900 },   // MacBook
    { width: 1536, height: 864 },   // Windows ноутбук
    { width: 1280, height: 720 },   // HD
    { width: 1600, height: 900 },   // 16:9
    { width: 2560, height: 1440 }   // 2K
  ];
  
  return viewports[Math.floor(Math.random() * viewports.length)];
}

/**
 * 5. Human-like scrolling
 * Имитирует поведение человека: скроллим вниз, читаем, возвращаемся вверх
 */
async function humanLikeScroll(page, options = {}) {
  const {
    scrollSteps = 3,
    scrollDistance = { min: 200, max: 500 },
    scrollDelay = { min: 800, max: 2000 },
    scrollBack = true
  } = options;

  // Скролл вниз несколько раз
  for (let i = 0; i < scrollSteps; i++) {
    const distance = Math.floor(
      Math.random() * (scrollDistance.max - scrollDistance.min) + scrollDistance.min
    );
    
    await page.evaluate((dist) => {
      window.scrollBy({
        top: dist,
        behavior: 'smooth'
      });
    }, distance);
    
    await randomDelay(scrollDelay.min, scrollDelay.max);
  }
  
  // Иногда возвращаемся вверх (как человек)
  if (scrollBack && Math.random() > 0.3) {
    const backDistance = Math.floor(Math.random() * 300 + 100);
    await page.evaluate((dist) => {
      window.scrollBy({
        top: -dist,
        behavior: 'smooth'
      });
    }, backDistance);
    
    await randomDelay(500, 1500);
  }
}

/**
 * 6. Mouse movement simulation (ghost cursor)
 * Для Playwright - используй ghost-cursor npm пакет
 */
async function moveMouseRandomly(page) {
  // Случайное движение мыши по странице
  const viewport = await page.viewportSize();
  if (!viewport) return;
  
  const x = Math.floor(Math.random() * viewport.width);
  const y = Math.floor(Math.random() * viewport.height);
  
  await page.mouse.move(x, y, { steps: Math.floor(Math.random() * 10 + 5) });
  await randomDelay(100, 500);
}

/**
 * 7. Rate Limiter
 * Ограничивает количество запросов в единицу времени
 */
class RateLimiter {
  constructor(maxRequests = 5, perSeconds = 10) {
    this.maxRequests = maxRequests;
    this.perSeconds = perSeconds * 1000;
    this.queue = [];
    this.stats = {
      total: 0,
      throttled: 0,
      avgWaitTime: 0
    };
  }

  async execute(fn) {
    const now = Date.now();
    this.queue = this.queue.filter(time => now - time < this.perSeconds);
    
    if (this.queue.length >= this.maxRequests) {
      this.stats.throttled++;
      const oldestRequest = this.queue[0];
      const waitTime = this.perSeconds - (now - oldestRequest) + Math.random() * 1000;
      
      this.stats.avgWaitTime = 
        (this.stats.avgWaitTime * this.stats.throttled + waitTime) / (this.stats.throttled + 1);
      
      console.log(`⏳ Rate limit: waiting ${Math.floor(waitTime)}ms`);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
    
    this.queue.push(Date.now());
    this.stats.total++;
    return await fn();
  }
  
  getStats() {
    return {
      ...this.stats,
      currentRate: this.queue.length,
      throttleRate: (this.stats.throttled / this.stats.total * 100).toFixed(2) + '%'
    };
  }
}

/**
 * 8. Request pattern randomization
 * Добавляет случайность в порядок обработки URLs
 */
function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

/**
 * 9. Time-based delay (имитация рабочего дня)
 * Большие задержки ночью, меньшие днём
 */
function getTimeBasedDelay() {
  const hour = new Date().getHours();
  
  // Ночь (00:00-06:00): большие задержки
  if (hour >= 0 && hour < 6) {
    return { min: 10000, max: 20000 }; // 10-20s
  }
  
  // Утро/день (06:00-22:00): средние задержки
  if (hour >= 6 && hour < 22) {
    return { min: 3000, max: 8000 };   // 3-8s
  }
  
  // Вечер (22:00-00:00): увеличенные задержки
  return { min: 5000, max: 12000 };    // 5-12s
}

/**
 * 10. Stealth mode configuration for Playwright
 * Настройки для максимальной скрытности
 */
function getStealthConfig() {
  return {
    // Random viewport
    viewport: getRandomViewport(),
    
    // Random User-Agent
    userAgent: getRandomUserAgent(),
    
    // Locale
    locale: 'en-US',
    timezoneId: 'America/New_York',
    
    // Permissions
    permissions: [],
    
    // Extra HTTP headers
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Cache-Control': 'max-age=0'
    },
    
    // Device scale factor (retina displays)
    deviceScaleFactor: Math.random() > 0.5 ? 2 : 1,
    
    // Mobile emulation (опционально)
    isMobile: false,
    hasTouch: false
  };
}

/**
 * 11. Session fingerprint generator
 * Генерирует уникальный fingerprint для сессии
 */
function generateSessionFingerprint() {
  const viewport = getRandomViewport();
  const userAgent = getRandomUserAgent();
  
  return {
    id: `session-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    viewport,
    userAgent,
    timestamp: new Date().toISOString(),
    platform: userAgent.includes('Windows') ? 'Win32' : 
              userAgent.includes('Mac') ? 'MacIntel' : 'Linux x86_64',
    hardwareConcurrency: [2, 4, 8, 16][Math.floor(Math.random() * 4)],
    deviceMemory: [2, 4, 8, 16][Math.floor(Math.random() * 4)]
  };
}

/**
 * 12. Intelligent retry with exponential backoff
 * Умные повторы с увеличением задержки
 */
async function retryWithBackoff(fn, maxRetries = 3, baseDelay = 1000) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries - 1) {
        throw error;
      }
      
      const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
      console.log(`⚠️ Attempt ${attempt + 1} failed, retrying in ${Math.floor(delay)}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

/**
 * 13. Detection checker
 * Проверяет была ли детектирована автоматизация
 */
async function checkIfDetected(page) {
  const detectionSignals = await page.evaluate(() => {
    return {
      // Проверка на captcha
      hasCaptcha: !!(
        document.querySelector('iframe[src*="recaptcha"]') ||
        document.querySelector('.g-recaptcha') ||
        document.querySelector('[data-sitekey]') ||
        document.body.innerText.toLowerCase().includes('captcha')
      ),
      
      // Проверка на блокировку
      isBlocked: !!(
        document.body.innerText.toLowerCase().includes('access denied') ||
        document.body.innerText.toLowerCase().includes('blocked') ||
        document.title.toLowerCase().includes('403')
      ),
      
      // Проверка на Cloudflare challenge
      hasCloudflare: !!(
        document.querySelector('.cf-browser-verification') ||
        document.body.innerText.includes('Checking your browser')
      )
    };
  });
  
  return detectionSignals;
}

module.exports = {
  // Основные утилиты
  randomDelay,
  smartDelay,
  getRandomUserAgent,
  getRandomViewport,
  humanLikeScroll,
  moveMouseRandomly,
  
  // Rate limiting
  RateLimiter,
  
  // Дополнительные
  shuffleArray,
  getTimeBasedDelay,
  getStealthConfig,
  generateSessionFingerprint,
  retryWithBackoff,
  checkIfDetected
};
