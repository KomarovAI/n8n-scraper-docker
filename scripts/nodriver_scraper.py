#!/usr/bin/env python3
import asyncio
import json
import os
import sys
from pydantic import BaseModel, HttpUrl

class ScrapedData(BaseModel):
    url: str
    content: str
    title: str
    metadata: dict
    timestamp: str
    runner: str = "nodriver"

async def scrape_with_nodriver(url: str, selector: str = "body"):
    '''
    Scrape website using Nodriver (undetected-chromedriver successor)
    Handles Cloudflare, Datadome, and other anti-bot systems
    '''
    try:
        import nodriver as uc
        from datetime import datetime
        
        print(f"[Nodriver] Starting scrape: {url}")
        
        # Start browser with stealth settings
        browser = await uc.start(
            headless=True,
            browser_args=[
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--disable-blink-features=AutomationControlled'
            ]
        )
        
        # Navigate to URL
        page = await browser.get(url)
        
        # Wait for selector
        await page.wait_for(selector, timeout=30)
        await asyncio.sleep(2)  # Extra wait for dynamic content
        
        # Extract data
        title = await page.evaluate("document.title")
        content = await page.evaluate(
            f"document.querySelector('{selector}')?.textContent || document.body.textContent"
        )
        
        # Get metadata
        meta_description = await page.evaluate(
            "document.querySelector('meta[name=\"description\"]')?.content || ''"
        )
        
        result = ScrapedData(
            url=url,
            content=content.strip() if content else "",
            title=title or "No title",
            metadata={
                "description": meta_description,
                "length": len(content) if content else 0,
                "selector": selector
            },
            timestamp=datetime.utcnow().isoformat()
        )
        
        await browser.stop()
        print(f"[Nodriver] Success: {len(result.content)} characters extracted")
        
        return result
        
    except Exception as e:
        print(f"[Nodriver] Error: {str(e)}", file=sys.stderr)
        raise

async def main():
    url = os.getenv('SCRAPE_URL')
    selector = os.getenv('SCRAPE_SELECTOR', 'body')
    request_id = os.getenv('REQUEST_ID')
    
    if not url:
        print("Error: SCRAPE_URL not provided", file=sys.stderr)
        sys.exit(1)
    
    try:
        result = await scrape_with_nodriver(url, selector)
        
        # Save results
        output = {
            "success": True,
            "requestId": request_id,
            "data": result.dict()
        }
        
        with open('output.json', 'w') as f:
            json.dump(output, f, indent=2)
        
        print(f"Results saved to output.json")
        
    except Exception as e:
        # Save error
        output = {
            "success": False,
            "requestId": request_id,
            "error": str(e)
        }
        
        with open('output.json', 'w') as f:
            json.dump(output, f, indent=2)
        
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
