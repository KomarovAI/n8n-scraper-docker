import os
import asyncio
from scrapers.image_downloader import ImageDownloader

async def scrape_with_switch(html, base_url, download_images=False):
    data = {}
    # extract info (placeholder, integrate your info-extraction logic)
    data['info'] = extract_info(html)
    if download_images:
        # обогащаем инфу картинками при выбранном режиме
        img_dl = ImageDownloader()
        urls = img_dl.extract_image_urls(html, base_url)
        downloaded = await img_dl.download_images(urls)
        data['images'] = downloaded
    return data

def extract_info(html):
    # placeholder: info extraction logic (JSON, text, etc)
    return {'text': 'extracted site data!'}

# Пример использования:
# asyncio.run(scrape_with_switch(html, url, download_images=True))
