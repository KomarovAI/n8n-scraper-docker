// ✅ FIX #11: Page pooling for better performance
// ✅ FIX #13: Connection pooling implementation
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const { createCursor } = require('ghost-cursor');
const winston = require('winston');

puppeteer.use(StealthPlugin());

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

class PuppeteerStealthScraperV2 {
  constructor(options = {}) {
    this.options = {
      headless: options.headless !== false,
      timeout: options.timeout || 30000,
      userAgent: options.userAgent || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: options.viewport || { width: 1920, height: 1080 },
      proxy: options.proxy || null,
      maxPoolSize: options.maxPoolSize || 10,
      ...options
    };
    this.browser = null;
    this.pagePool = [];
    this.activePages = new Set();
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
    logger.info('Browser launched successfully with page pooling enabled');
    return this.browser;
  }

  // ✅ FIX #11: Get page from pool or create new
  async getPage() {
    if (this.pagePool.length > 0) {
      const page = this.pagePool.pop();
      this.activePages.add(page);
      logger.debug(`Reusing page from pool (pool size: ${this.pagePool.length})`);
      return page;
    }

    // Create new page if pool is empty
    const page = await this.browser.newPage();
    this.activePages.add(page);
    logger.debug(`Created new page (active: ${this.activePages.size})`);
    return page;
  }

  // ✅ FIX #11: Release page back to pool
  async releasePage(page) {
    this.activePages.delete(page);

    if (this.pagePool.length < this.options.maxPoolSize) {
      try {
        // Reset page state
        await page.goto('about:blank', { waitUntil: 'domcontentloaded', timeout: 5000 });
        
        // Clear cookies and cache
        const client = await page.target().createCDPSession();
        await client.send('Network.clearBrowserCookies');
        await client.send('Network.clearBrowserCache');
        await client.detach();

        this.pagePool.push(page);
        logger.debug(`Page returned to pool (pool size: ${this.pagePool.length})`);
      } catch (error) {
        logger.warn(`Failed to reset page, closing: ${error.message}`);
        await page.close().catch(() => {});
      }
    } else {
      // Pool is full, close the page
      await page.close().catch(() => {});
      logger.debug(`Pool full, page closed (pool size: ${this.pagePool.length})`);
    }
  }

  async scrape(url) {
    if (!this.browser) {
      await this.launch();
    }

    const page = await this.getPage();
    const startTime = Date.now();

    try {
      await page.setViewport(this.options.viewport);
      await page.setUserAgent(this.options.userAgent);
      
      // Anti-detection measures
      await page.evaluateOnNewDocument(() => {
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
        Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
        Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
        
        const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
        HTMLCanvasElement.prototype.toDataURL = function() {
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
      
      // Human-like cursor movement
      const cursor = createCursor(page);
      await cursor.move(Math.random() * 500 + 100, Math.random() * 500 + 100);
      
      // Random delay
      await new Promise(resolve => setTimeout(resolve, Math.random() * 2000 + 1000));
      
      const content = await page.evaluate(() => {
        return {
          title: document.title,
          html: document.documentElement.outerHTML,
          text: document.body.innerText,
          url: window.location.href,
          timestamp: new Date().toISOString()
        };
      });
      
      const duration = Date.now() - startTime;
      logger.info(`Successfully scraped ${url} in ${duration}ms`);
      
      return { 
        success: true, 
        data: content, 
        error: null,
        duration,
        fromPool: true
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error(`Failed to scrape ${url}: ${error.message}`);
      return { 
        success: false, 
        data: null, 
        error: error.message,
        duration
      };
    } finally {
      await this.releasePage(page);
    }
  }

  async close() {
    // Close all pages in pool
    logger.info(`Closing page pool (${this.pagePool.length} pages)`);
    await Promise.all(
      this.pagePool.map(page => page.close().catch(() => {}))
    );
    this.pagePool = [];

    // Close all active pages
    logger.info(`Closing active pages (${this.activePages.size} pages)`);
    await Promise.all(
      Array.from(this.activePages).map(page => page.close().catch(() => {}))
    );
    this.activePages.clear();

    // Close browser
    if (this.browser) {
      await this.browser.close();
      logger.info('Browser closed');
    }
  }

  // Get pool statistics
  getPoolStats() {
    return {
      poolSize: this.pagePool.length,
      activePages: this.activePages.size,
      maxPoolSize: this.options.maxPoolSize
    };
  }
}

if (require.main === module) {
  (async () => {
    const scraper = new PuppeteerStealthScraperV2({ 
      headless: true, 
      timeout: 30000,
      maxPoolSize: 5
    });
    
    const urls = [
      'https://example.com',
      'https://httpbin.org/headers',
      'https://www.wikipedia.org',
      'https://github.com'
    ];
    
    console.log('Starting scraping with page pooling...');
    
    for (const url of urls) {
      const result = await scraper.scrape(url);
      console.log(`\n${url}:`);
      console.log(`  Success: ${result.success}`);
      console.log(`  Duration: ${result.duration}ms`);
      console.log(`  Pool stats:`, scraper.getPoolStats());
      
      if (result.success) {
        console.log(`  Title: ${result.data.title}`);
      } else {
        console.log(`  Error: ${result.error}`);
      }
    }
    
    console.log('\nFinal pool stats:', scraper.getPoolStats());
    await scraper.close();
  })();
}

module.exports = PuppeteerStealthScraperV2;
