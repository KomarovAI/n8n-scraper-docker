#!/usr/bin/env python3
'''
Enhanced Nodriver Batch Scraper
Implements all 22 best practices from n8n-ai-automation
'''

import asyncio
import json
import os
import sys
import logging
from datetime import datetime
from typing import List, Dict, Optional
from pydantic import BaseModel, HttpUrl, validator

# Setup structured logging
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","level":"%(levelname)s","message":"%(message)s"}',
    handlers=[
        logging.FileHandler('scraper.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Data models
class ScrapedData(BaseModel):
    url: str
    success: bool
    title: Optional[str] = None
    description: Optional[str] = None
    text_content: Optional[str] = None
    html: Optional[str] = None
    links: List[Dict] = []
    images: List[Dict] = []
    meta: Dict = {}
    timestamp: str
    runner: str = "nodriver"
    execution_time_ms: Optional[int] = None
    error: Optional[str] = None
    retry_count: int = 0

# Constants
MAX_RETRIES = 3
BASE_DELAY = 2000  # ms
TIMEOUT = 30000  # ms
MAX_HTML_SIZE = 100_000  # 100KB
MAX_TEXT_SIZE = 50_000  # 50KB

async def retry_with_backoff(fn, url, retries=MAX_RETRIES):
    '''Exponential backoff retry logic'''
    for attempt in range(retries):
        try:
            return await fn(url, attempt)
        except Exception as error:
            if attempt == retries - 1:
                raise error
            
            delay = (BASE_DELAY * (2 ** attempt)) / 1000  # Convert to seconds
            logger.warning(f"Attempt {attempt + 1} failed for {url}: {str(error)}. Retrying in {delay}s...")
            await asyncio.sleep(delay)

async def scrape_with_nodriver(url: str, attempt: int = 0):
    '''
    Enhanced Nodriver scraping with:
    - Cloudflare bypass
    - Smart content extraction
    - Resource limits
    - Error categorization
    '''
    start_time = datetime.now()
    
    try:
        import nodriver as uc
        from bs4 import BeautifulSoup
        
        logger.info(f"[Nodriver] Starting scrape: {url} (attempt {attempt + 1})")
        
        # Start browser with enhanced stealth
        browser = await uc.start(
            headless=True,
            browser_args=[
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-blink-features=AutomationControlled',
                '--disable-accelerated-2d-canvas',
                '--disable-gpu',
                '--window-size=1920,1080',
                '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            ]
        )
        
        try:
            # Navigate with timeout
            page = await browser.get(url, timeout=TIMEOUT / 1000)
            
            # Wait for body
            await page.wait_for('body', timeout=5)
            
            # Extra wait for dynamic content
            await asyncio.sleep(2)
            
            # Get HTML
            html = await page.evaluate('document.documentElement.outerHTML')
            
            # Parse with BeautifulSoup
            soup = BeautifulSoup(html, 'lxml')
            
            # Extract metadata
            title = soup.find('title')
            title = title.get_text() if title else ''
            
            description_tag = soup.find('meta', attrs={'name': 'description'})
            description = description_tag.get('content', '') if description_tag else ''
            
            # Priority-based content extraction
            main_content = None
            for selector in ['main', 'article', '[class*="content"]', 'body']:
                element = soup.select_one(selector)
                if element:
                    main_content = element.get_text(separator=' ', strip=True)
                    if len(main_content) > 200:  # Minimum viable content
                        break
            
            # Clean text
            clean_text = ' '.join(main_content.split()) if main_content else ''
            clean_text = clean_text[:MAX_TEXT_SIZE]
            
            # Extract links (limited to 100)
            links = []
            for a in soup.find_all('a', href=True, limit=100):
                href = a.get('href', '')
                if href and not href.startswith('#'):
                    links.append({
                        'url': href,
                        'text': a.get_text(strip=True)[:200]
                    })
            
            # Extract images (limited to 50)
            images = []
            for img in soup.find_all('img', src=True, limit=50):
                images.append({
                    'url': img.get('src', ''),
                    'alt': img.get('alt', ''),
                    'width': img.get('width'),
                    'height': img.get('height')
                })
            
            execution_time = int((datetime.now() - start_time).total_seconds() * 1000)
            
            result = ScrapedData(
                url=url,
                success=True,
                title=title,
                description=description,
                text_content=clean_text,
                html=html[:MAX_HTML_SIZE],
                links=links,
                images=images,
                meta={
                    'text_length': len(clean_text),
                    'html_size': len(html),
                    'links_count': len(links),
                    'images_count': len(images)
                },
                timestamp=datetime.utcnow().isoformat(),
                execution_time_ms=execution_time,
                retry_count=attempt
            )
            
            logger.info(f"[Nodriver] Success: {url} ({execution_time}ms, {len(clean_text)} chars)")
            return result
            
        finally:
            await browser.stop()
            
    except Exception as e:
        execution_time = int((datetime.now() - start_time).total_seconds() * 1000)
        logger.error(f"[Nodriver] Error: {url} - {str(e)}")
        
        # Error categorization
        error_type = 'unknown'
        if 'timeout' in str(e).lower():
            error_type = 'timeout'
        elif 'dns' in str(e).lower() or 'connection' in str(e).lower():
            error_type = 'network'
        elif '403' in str(e) or '429' in str(e):
            error_type = 'anti_bot'
        elif '404' in str(e) or '500' in str(e):
            error_type = 'content'
        
        return ScrapedData(
            url=url,
            success=False,
            error=f"[{error_type}] {str(e)}",
            timestamp=datetime.utcnow().isoformat(),
            execution_time_ms=execution_time,
            retry_count=attempt
        )

async def process_batch(urls_data: List[Dict]):
    '''Process batch of URLs with concurrent execution'''
    results = {'successful': [], 'failed': []}
    
    # Semaphore for concurrency limit (max 5 concurrent)
    semaphore = asyncio.Semaphore(5)
    
    async def scrape_with_limit(url_data):
        async with semaphore:
            try:
                result = await retry_with_backoff(scrape_with_nodriver, url_data['url'])
                
                if result.success:
                    results['successful'].append(result.dict())
                else:
                    results['failed'].append({
                        'url': result.url,
                        'error': result.error,
                        'runner': 'nodriver'
                    })
            except Exception as e:
                results['failed'].append({
                    'url': url_data['url'],
                    'error': str(e),
                    'runner': 'nodriver'
                })
    
    # Execute all scraping tasks concurrently
    await asyncio.gather(*[scrape_with_limit(url_data) for url_data in urls_data])
    
    return results

async def main():
    batch_id = os.getenv('BATCH_ID', 'unknown')
    urls_json = os.getenv('URLS_JSON', '[]')
    
    try:
        urls_data = json.loads(urls_json)
        
        if not urls_data:
            raise ValueError('No URLs provided')
        
        logger.info(f"Starting batch {batch_id} with {len(urls_data)} URLs")
        
        # Process batch
        results = await process_batch(urls_data)
        
        # Add batch metadata
        results['batch_id'] = batch_id
        results['timestamp'] = datetime.utcnow().isoformat()
        results['stats'] = {
            'total': len(urls_data),
            'successful': len(results['successful']),
            'failed': len(results['failed']),
            'success_rate': f"{(len(results['successful']) / len(urls_data) * 100):.2f}%"
        }
        
        # Save results
        with open('results.json', 'w') as f:
            json.dump(results, f, indent=2)
        
        logger.info(f"Batch {batch_id} completed: {results['stats']}")
        
    except Exception as e:
        logger.error(f"Batch {batch_id} failed: {str(e)}")
        
        # Save error
        error_result = {
            'batch_id': batch_id,
            'success': False,
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        with open('results.json', 'w') as f:
            json.dump(error_result, f, indent=2)
        
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
