#!/usr/bin/env node
/**
 * Enhanced Playwright Batch Scraper
 * Implements all 22 best practices from n8n-ai-automation
 */

const { chromium } = require('playwright-extra');
const stealth = require('puppeteer-extra-plugin-stealth')();
const fs = require('fs').promises;
const path = require('path');

// Apply stealth plugin
chromium.use(stealth);

// Configuration
const MAX_RETRIES = 3;
const BASE_DELAY = 2000; // ms
const TIMEOUT = 30000; // ms
const MAX_HTML_SIZE = 100000; // 100KB
const MAX_TEXT_SIZE = 50000; // 50KB
const MAX_CONCURRENT = 5; // Parallel browser contexts

// Structured logging
const logger = {
  log: (level, message, data = {}) => {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...data
    };
    console.log(JSON.stringify(entry));
  },
  info: (msg, data) => logger.log('info', msg, data),
  warn: (msg, data) => logger.log('warning', msg, data),
  error: (msg, data) => logger.log('error', msg, data)
};

/**
 * Retry with exponential backoff
 */
async function retryWithBackoff(fn, url, retries = MAX_RETRIES) {
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      return await fn(url, attempt);
    } catch (error) {
      if (attempt === retries - 1) throw error;
      
      const delay = BASE_DELAY * Math.pow(2, attempt);
      logger.warn(`Attempt ${attempt + 1} failed for ${url}: ${error.message}. Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

/**
 * Enhanced Playwright scraping with best practices
 */
async function scrapeWithPlaywright(url, attempt = 0) {
  const startTime = Date.now();
  
  logger.info(`[Playwright] Starting scrape: ${url} (attempt ${attempt + 1})`);
  
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-blink-features=AutomationControlled',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920,1080'
    ]
  });
  
  try {
    const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1920, height: 1080 },
      locale: 'en-US',
      timezoneId: 'America/New_York'
    });
    
    const page = await context.newPage();
    
    // Enhanced headers
    await page.setExtraHTTPHeaders({
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1'
    });
    
    // Navigate with networkidle
    await page.goto(url, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT
    });
    
    // Wait for body
    await page.waitForSelector('body', { timeout: 5000 });
    
    // Extract data with priority-based selectors
    const data = await page.evaluate(() => {
      // Priority-based content extraction
      const getMainContent = () => {
        const selectors = ['main', 'article', '[class*=\"content\"]', 'body'];
        for (const selector of selectors) {
          const element = document.querySelector(selector);
          if (element) {
            const text = element.textContent || '';
            if (text.trim().length > 200) return text;
          }
        }
        return document.body.textContent || '';
      };
      
      // Extract metadata
      const title = document.title || document.querySelector('meta[property=\"og:title\"]')?.content || '';
      const description = document.querySelector('meta[name=\"description\"]')?.content || 
                         document.querySelector('meta[property=\"og:description\"]')?.content || '';
      
      // Extract links (limited to 100)
      const links = Array.from(document.querySelectorAll('a[href]'))
        .slice(0, 100)
        .map(a => ({
          url: a.href,
          text: (a.textContent || '').trim().substring(0, 200)
        }))
        .filter(link => link.url && !link.url.startsWith('#'));
      
      // Extract images (limited to 50)
      const images = Array.from(document.querySelectorAll('img[src]'))
        .slice(0, 50)
        .map(img => ({
          url: img.src,
          alt: img.alt || '',
          width: img.width || null,
          height: img.height || null
        }));
      
      return {
        html: document.documentElement.outerHTML,
        title,
        description,
        mainContent: getMainContent(),
        links,
        images,
        url: window.location.href
      };
    });
    
    await browser.close();
    
    // Clean text
    const cleanText = data.mainContent
      .replace(/\s+/g, ' ')
      .replace(/\n+/g, '\n')
      .trim()
      .substring(0, MAX_TEXT_SIZE);
    
    const executionTime = Date.now() - startTime;
    
    const result = {
      url: data.url,
      success: true,
      title: data.title,
      description: data.description,
      text_content: cleanText,
      html: data.html.substring(0, MAX_HTML_SIZE),
      links: data.links,
      images: data.images,
      meta: {
        text_length: cleanText.length,
        html_size: data.html.length,
        links_count: data.links.length,
        images_count: data.images.length
      },
      timestamp: new Date().toISOString(),
      runner: 'playwright',
      execution_time_ms: executionTime,
      retry_count: attempt
    };
    
    logger.info(`[Playwright] Success: ${url} (${executionTime}ms, ${cleanText.length} chars)`);
    return result;
    
  } catch (error) {
    await browser.close();
    
    const executionTime = Date.now() - startTime;
    logger.error(`[Playwright] Error: ${url} - ${error.message}`);
    
    // Error categorization
    let errorType = 'unknown';
    const errorMsg = error.message.toLowerCase();
    if (errorMsg.includes('timeout')) errorType = 'timeout';
    else if (errorMsg.includes('dns') || errorMsg.includes('connection')) errorType = 'network';
    else if (errorMsg.includes('403') || errorMsg.includes('429')) errorType = 'anti_bot';
    else if (errorMsg.includes('404') || errorMsg.includes('500')) errorType = 'content';
    
    return {
      url,
      success: false,
      error: `[${errorType}] ${error.message}`,
      timestamp: new Date().toISOString(),
      runner: 'playwright',
      execution_time_ms: executionTime,
      retry_count: attempt
    };
  }
}

/**
 * Process batch with concurrency control
 */
async function processBatch(urlsData) {
  const results = { successful: [], failed: [] };
  const queue = [...urlsData];
  const executing = [];
  
  while (queue.length > 0 || executing.length > 0) {
    // Start new tasks up to MAX_CONCURRENT
    while (queue.length > 0 && executing.length < MAX_CONCURRENT) {
      const urlData = queue.shift();
      
      const task = (async () => {
        try {
          const result = await retryWithBackoff(scrapeWithPlaywright, urlData.url);
          
          if (result.success) {
            results.successful.push(result);
          } else {
            results.failed.push({
              url: result.url,
              error: result.error,
              runner: 'playwright'
            });
          }
        } catch (error) {
          results.failed.push({
            url: urlData.url,
            error: error.message,
            runner: 'playwright'
          });
        }
      })();
      
      executing.push(task);
    }
    
    // Wait for at least one task to complete
    if (executing.length > 0) {
      await Promise.race(executing);
      executing.splice(executing.findIndex(task => task.isCompleted), 1);
    }
  }
  
  return results;
}

/**
 * Main execution
 */
async function main() {
  const batchId = process.env.BATCH_ID || 'unknown';
  const urlsJson = process.env.URLS_JSON || '[]';
  
  // Setup log file
  const logStream = await fs.open('scraper.log', 'a');
  
  try {
    const urlsData = JSON.parse(urlsJson);
    
    if (!urlsData || urlsData.length === 0) {
      throw new Error('No URLs provided');
    }
    
    logger.info(`Starting batch ${batchId} with ${urlsData.length} URLs`);
    
    // Process batch
    const results = await processBatch(urlsData);
    
    // Add batch metadata
    results.batch_id = batchId;
    results.timestamp = new Date().toISOString();
    results.stats = {
      total: urlsData.length,
      successful: results.successful.length,
      failed: results.failed.length,
      success_rate: `${((results.successful.length / urlsData.length) * 100).toFixed(2)}%`
    };
    
    // Save results
    await fs.writeFile('results.json', JSON.stringify(results, null, 2));
    
    logger.info(`Batch ${batchId} completed`, results.stats);
    
  } catch (error) {
    logger.error(`Batch ${batchId} failed: ${error.message}`);
    
    // Save error
    const errorResult = {
      batch_id: batchId,
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    };
    
    await fs.writeFile('results.json', JSON.stringify(errorResult, null, 2));
    process.exit(1);
    
  } finally {
    await logStream.close();
  }
}

main();
