#!/usr/bin/env node
const { chromium } = require('playwright-extra');
const stealth = require('puppeteer-extra-plugin-stealth')();
const fs = require('fs');

// Apply stealth plugin
chromium.use(stealth);

async function scrapeWithPlaywright(url, selector = 'body') {
  console.log(`[Playwright] Starting scrape: ${url}`);
  
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-blink-features=AutomationControlled'
    ]
  });
  
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    viewport: { width: 1920, height: 1080 },
    locale: 'en-US'
  });
  
  const page = await context.newPage();
  
  try {
    // Navigate with networkidle wait
    await page.goto(url, { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    // Wait for selector
    await page.waitForSelector(selector, { timeout: 10000 });
    
    // Extract data
    const data = await page.evaluate((sel) => {
      return {
        title: document.title,
        content: document.querySelector(sel)?.textContent || document.body.textContent,
        description: document.querySelector('meta[name="description"]')?.content || '',
        url: window.location.href
      };
    }, selector);
    
    console.log(`[Playwright] Success: ${data.content.length} characters extracted`);
    
    await browser.close();
    
    return {
      success: true,
      data: {
        ...data,
        content: data.content.trim(),
        metadata: {
          description: data.description,
          length: data.content.length,
          selector: selector
        },
        timestamp: new Date().toISOString(),
        runner: 'playwright'
      }
    };
    
  } catch (error) {
    await browser.close();
    throw error;
  }
}

async function main() {
  const url = process.env.SCRAPE_URL;
  const selector = process.env.SCRAPE_SELECTOR || 'body';
  const requestId = process.env.REQUEST_ID;
  
  if (!url) {
    console.error('Error: SCRAPE_URL not provided');
    process.exit(1);
  }
  
  try {
    const result = await scrapeWithPlaywright(url, selector);
    result.requestId = requestId;
    
    // Save results
    fs.writeFileSync('output.json', JSON.stringify(result, null, 2));
    console.log('Results saved to output.json');
    
  } catch (error) {
    // Save error
    const errorOutput = {
      success: false,
      requestId,
      error: error.message
    };
    
    fs.writeFileSync('output.json', JSON.stringify(errorOutput, null, 2));
    console.error(`[Playwright] Error: ${error.message}`);
    process.exit(1);
  }
}

main();
