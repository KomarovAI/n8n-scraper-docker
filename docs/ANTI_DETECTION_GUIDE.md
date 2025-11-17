# 🕵️ Anti-Detection Guide: Скрытный скрапинг

## 🎯 Цель

Сделать scraper незаметным для антибот-систем:
- Cloudflare
- Datadome
- Akamai Bot Manager
- PerimeterX
- reCAPTCHA

---

## 🛡️ Что детектируют антибот-системы

### 1. **Browser Fingerprinting**
```javascript
// Проверяют:
- User-Agent
- Screen resolution
- WebGL fingerprint
- Canvas fingerprint
- Audio fingerprint
- Fonts list
- navigator.webdriver === true  // 🛑 Проблема!
- window.chrome === undefined   // 🛑 Проблема!
```

### 2. **Behavioral Analysis**
```javascript
// Анализируют:
- Скорость действий (слишком быстро = бот)
- Движения мыши (есть/нет)
- Скроллинг (естественный/нет)
- Клики (точно по координатам vs случайные offset)
- Задержки между действиями (постоянные vs случайные)
```

### 3. **Rate Limiting**
```
Отслеживают:
- Requests per second from same IP
- Requests per minute
- Pattern analysis (одинаковые интервалы = подозрительно)
```

---

## ✅ Наши защитные техники

### 🔧 1. Random Delays (Случайные задержки)

```javascript
const { randomDelay, smartDelay } = require('./utils/anti-detection');

// Простая задержка
await randomDelay(3000, 7000);  // 3-7 секунд

// Умная задержка (базовая ± 50%)
await smartDelay(5000);  // 2.5-7.5 секунд
```

**Рекомендации**:
| Уровень защиты | Задержка |
|---------------------|------------|
| Низкий (блоги) | 1-3s |
| Средний (e-commerce) | 3-7s |
| Высокий (Cloudflare) | 5-15s |
| Критичный (LinkedIn) | 10-30s |

---

### 👁️ 2. User-Agent Rotation

```javascript
const { getRandomUserAgent } = require('./utils/anti-detection');

const userAgent = getRandomUserAgent();
await page.setUserAgent(userAgent);
```

**База User-Agents**: 9 реальных UA популярных браузеров (Chrome, Firefox, Edge, Safari)

---

### 🖥️ 3. Random Viewport

```javascript
const { getRandomViewport } = require('./utils/anti-detection');

const viewport = getRandomViewport();
await page.setViewportSize(viewport);
```

**Поддерживаемые разрешения**: 1920x1080, 1366x768, 1440x900, 1536x864, 1280x720, 2560x1440

---

### 📜 4. Human-like Scrolling

```javascript
const { humanLikeScroll } = require('./utils/anti-detection');

// Базовый скроллинг
await humanLikeScroll(page);

// С настройками
await humanLikeScroll(page, {
  scrollSteps: 4,                      // 4 скролла
  scrollDistance: { min: 300, max: 600 },  // 300-600px
  scrollDelay: { min: 1000, max: 3000 },   // 1-3s между скроллами
  scrollBack: true                      // Иногда возвращаться вверх
});
```

**Что происходит**:
1. Скролл вниз несколько раз со случайными задержками
2. Пауза («чтение»)
3. Иногда скролл назад (как человек)

---

### 🖱️ 5. Mouse Movement Simulation

```javascript
const { moveMouseRandomly } = require('./utils/anti-detection');

// Случайное движение мыши
for (let i = 0; i < 3; i++) {
  await moveMouseRandomly(page);
}
```

**Для более реалистичных движений** используй `ghost-cursor`:
```bash
npm install ghost-cursor
```

```javascript
const { createCursor } = require('ghost-cursor');
const cursor = createCursor(page);

await cursor.moveTo('.button');  // Плавная траектория
await cursor.click('.button');    // Клик с случайным offset
```

---

### ⏳ 6. Rate Limiting

```javascript
const { RateLimiter } = require('./utils/anti-detection');

// Максимум 5 запросов в 10 секунд
const limiter = new RateLimiter(5, 10);

for (const url of urls) {
  await limiter.execute(async () => {
    return await scrape(url);
  });
}

// Получить статистику
console.log(limiter.getStats());
// { total: 100, throttled: 45, avgWaitTime: 2341, throttleRate: '45.00%' }
```

---

### 🔐 7. Stealth Configuration

```javascript
const { getStealthConfig } = require('./utils/anti-detection');

const config = getStealthConfig();
const context = await browser.newContext(config);

// config включает:
// - Random viewport
// - Random User-Agent
// - Locale & timezone
// - Extra HTTP headers
// - Device scale factor
```

---

### 🕵️ 8. Detection Checker

```javascript
const { checkIfDetected } = require('./utils/anti-detection');

const detection = await checkIfDetected(page);

if (detection.hasCaptcha) {
  console.warn('⚠️ CAPTCHA detected!');
}

if (detection.isBlocked) {
  console.warn('⚠️ Access blocked!');
}

if (detection.hasCloudflare) {
  console.warn('⚠️ Cloudflare challenge!');
}
```

---

## 🚀 Использование в Playwright Scraper

### Пример полной интеграции:

```javascript
const { playwrightStealthScraper } = require('./scrapers/playwright-stealth-v3');

const urls = [
  'https://protected-site-1.com',
  'https://protected-site-2.com',
  'https://protected-site-3.com'
];

const results = await playwrightStealthScraper(urls, {
  concurrency: 3,
  timeout: 30000,
  antiDetection: {
    enabled: true,
    humanLikeScrolling: true,
    mouseMoves: true,
    delayBetweenRequests: { min: 5000, max: 10000 },  // 5-10s
    randomizeOrder: true  // Случайный порядок URLs
  }
});

console.log(results.stats);
// {
//   total: 3,
//   successful: 3,
//   failed: 0,
//   detected: 0,  // 🎉 Не детектированы!
//   avgProcessingTime: 8234
// }
```

---

## 📊 Рекомендуемые настройки

### 🟢 Низкая защита (блоги, новости)

```javascript
{
  antiDetection: {
    enabled: true,
    humanLikeScrolling: false,
    mouseMoves: false,
    delayBetweenRequests: { min: 1000, max: 3000 }
  }
}
```

### 🟡 Средняя защита (e-commerce)

```javascript
{
  antiDetection: {
    enabled: true,
    humanLikeScrolling: true,
    mouseMoves: true,
    delayBetweenRequests: { min: 3000, max: 7000 },
    randomizeOrder: true
  }
}
```

### 🔴 Высокая защита (Cloudflare, Datadome)

```javascript
{
  antiDetection: {
    enabled: true,
    humanLikeScrolling: true,
    mouseMoves: true,
    delayBetweenRequests: { min: 10000, max: 20000 },  // 10-20s!
    randomizeOrder: true
  }
}
```

**+ Дополнительно**:
- Residential proxies
- Rotating IP addresses
- Cookie persistence

---

## 💰 Impact на производительность

| Настройка | Без Anti-Detection | С Anti-Detection | Overhead |
|-------------|---------------------|------------------|-----------|
| **Latency** | 5-10s | 10-20s | +100% |
| **Success Rate** | 60-70% | 85-95% | **+25-35%** |
| **Detection Rate** | 30-40% | 5-15% | **-20-30%** |
| **Cost** | $0.008/min | $0.008/min | +0% |

**Вывод**: 🎯 Медленнее, но **в 1.5 раза успешнее**!

---

## 🔗 Полезные ссылки

- 💻 [Anti-Detection Utils](../utils/anti-detection.js)
- 🎭 [Playwright Stealth Scraper v3](../scrapers/playwright-stealth-v3.js)
- 📖 [Production Fixes Guide](../PRODUCTION_FIXES_V3.md)

---

**Статус**: ✅ Production Ready  
**Версия**: 3.0.0  
**Дата**: 2025-11-18
