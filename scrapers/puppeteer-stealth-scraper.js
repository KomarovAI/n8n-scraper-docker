const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const { createCursor } = require('ghost-cursor');
const winston = require('winston');

// Configure stealth plugin
puppeteer.use(StealthPlugin());

// Configure logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

class PuppeteerStealthScraper {
  constructor(options = {}) {
    this.options = {
      headless: options.headless !== false,
      timeout: options.timeout || 30000,
      userAgent: options.userAgent || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: options.viewport || { width: 1920, height: 1080 },
      proxy: options.proxy || null,
      ...options
    };
    this.browser = null;
  }

  async launch() {
    const launchOptions = {
      headless: this.options.headless ? 'new' : false,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu',
        '--window-size=1920,1080',
        '--disable-blink-features=AutomationControlled',
      ]
    };

    if (this.options.proxy) {
      launchOptions.args.push(`--proxy-server=${this.options.proxy}`);
    }

    this.browser = await puppeteer.launch(launchOptions);
    logger.info('Browser launched successfully');
    return this.browser;
  }

  async scrape(url) {
    if (!this.browser) {
      await this.launch();
    }

    const page = await this.browser.newPage();
    
    try {
      // Set viewport
      await page.setViewport(this.options.viewport);

      // Set user agent
      await page.setUserAgent(this.options.userAgent);

      // Inject anti-detection scripts
      await page.evaluateOnNewDocument(() => {
        // Override navigator.webdriver
        Object.defineProperty(navigator, 'webdriver', {
          get: () => undefined
        });

        // Override plugins
        Object.defineProperty(navigator, 'plugins', {
          get: () => [1, 2, 3, 4, 5]
        });

        // Override languages
        Object.defineProperty(navigator, 'languages', {
          get: () => ['en-US', 'en']
        });

        // Canvas fingerprinting randomization
        const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
        HTMLCanvasElement.prototype.toDataURL = function() {
          // Add slight randomization
          if (Math.random() > 0.99) {
            return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg';
          }
          return originalToDataURL.apply(this, arguments);
        };
      });

      logger.info(`Navigating to ${url}`);
      await page.goto(url, {
        waitUntil: 'networkidle2',
        timeout: this.options.timeout
      });

      // Human-like cursor movements
      const cursor = createCursor(page);
      await cursor.move(Math.random() * 500 + 100, Math.random() * 500 + 100);
      
      // Random delay to simulate human behavior
      await page.waitForTimeout(Math.random() * 2000 + 1000);

      // Extract page content
      const content = await page.evaluate(() => {
        return {
          title: document.title,
          html: document.documentElement.outerHTML,
          text: document.body.innerText,
          url: window.location.href,
          timestamp: new Date().toISOString()
        };
      });

      logger.info(`Successfully scraped ${url}`);
      return {
        success: true,
        data: content,
        error: null
      };

    } catch (error) {
      logger.error(`Failed to scrape ${url}: ${error.message}`);
      return {
        success: false,
        data: null,
        error: error.message
      };
    } finally {
      await page.close();
    }
  }

  async close() {
    if (this.browser) {
      await this.browser.close();
      logger.info('Browser closed');
    }
  }
}

// Example usage
if (require.main === module) {
  (async () => {
    const scraper = new PuppeteerStealthScraper({
      headless: true,
      timeout: 30000
    });

    const urls = [
      'https://example.com',
      'https://httpbin.org/headers'
    ];

    for (const url of urls) {
      const result = await scraper.scrape(url);
      console.log(JSON.stringify(result, null, 2));
    }

    await scraper.close();
  })();
}

module.exports = PuppeteerStealthScraper;
