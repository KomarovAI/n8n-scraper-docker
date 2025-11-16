import os
import re
import aiohttp
import aiofiles
from bs4 import BeautifulSoup
import asyncio
from urllib.parse import urljoin, urlparse

class ImageDownloader:
    def __init__(self, storage_dir='./downloaded_images'):
        self.storage_dir = storage_dir
        os.makedirs(self.storage_dir, exist_ok=True)

    def extract_image_urls(self, html, base_url):
        soup = BeautifulSoup(html, 'html.parser')
        urls = set()

        # <img src>
        for img in soup.find_all('img'):
            src = img.get('src')
            if src:
                full = urljoin(base_url, src)
                urls.add(full)
        # <img srcset> responsive images
        for img in soup.find_all('img'):
            srcset = img.get('srcset')
            if srcset:
                for candidate in srcset.split(','):
                    url_part = candidate.strip().split(' ')[0]
                    full = urljoin(base_url, url_part)
                    urls.add(full)
        # background-image
        for tag in soup.find_all(style=True):
            bg_match = re.search(r'background-image\s*:\s*url\(([^"]+)\)', tag['style'])
            if bg_match:
                full = urljoin(base_url, bg_match.group(1))
                urls.add(full)
        return list(urls)

    async def download_image(self, url):
        name = os.path.basename(urlparse(url).path) or 'unnamed.jpg'
        safe_name = re.sub(r'[^\w\.-]', '_', name)
        out_path = os.path.join(self.storage_dir, safe_name)
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, timeout=15) as resp:
                    if resp.status == 200 and 'image' in resp.headers.get('Content-Type', ''):
                        f = await aiofiles.open(out_path, mode='wb')
                        await f.write(await resp.read())
                        await f.close()
                        return out_path
        except Exception:
            pass
        return None

    async def download_images(self, urls):
        tasks = [self.download_image(url) for url in urls]
        return await asyncio.gather(*tasks)
