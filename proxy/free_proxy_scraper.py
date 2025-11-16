#!/usr/bin/env python3
"""
Free Proxy Scraper
Scrapes and validates free proxies from multiple sources.
"""

import asyncio
import aiohttp
import random
from typing import List, Dict, Optional
from loguru import logger
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass
class ProxyInfo:
    """Proxy information container."""
    ip: str
    port: int
    protocol: str
    country: str = "Unknown"
    anonymity: str = "Unknown"
    speed_ms: float = 999999
    last_checked: Optional[datetime] = None
    success_rate: float = 0.0

    @property
    def url(self) -> str:
        return f"{self.protocol}://{self.ip}:{self.port}"

    def __repr__(self):
        return f"Proxy({self.url} | {self.country} | {self.anonymity} | {self.speed_ms}ms)"


class FreeProxyManager:
    """
    Free Proxy Pool Manager.
    Fetches, validates, and maintains a pool of working free proxies.
    """

    # Public proxy list sources
    PROXY_SOURCES = [
        "https://api.proxyscrape.com/v2/?request=get&protocol=http&timeout=10000&country=all&ssl=all&anonymity=all",
        "https://www.proxy-list.download/api/v1/get?type=http",
        "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt",
        "https://raw.githubusercontent.com/ShiftyTR/Proxy-List/master/http.txt",
        "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt",
    ]

    def __init__(self, min_proxies: int = 50):
        self.proxies: List[ProxyInfo] = []
        self.min_proxies = min_proxies
        self.last_refresh: Optional[datetime] = None
        self.banlist: set = set()

    async def refresh_proxy_pool(self):
        """Fetch fresh proxies from all sources."""
        logger.info("Refreshing proxy pool...")
        all_proxies = []

        async with aiohttp.ClientSession() as session:
            tasks = [self._fetch_source(session, source) for source in self.PROXY_SOURCES]
            results = await asyncio.gather(*tasks, return_exceptions=True)

            for result in results:
                if isinstance(result, list):
                    all_proxies.extend(result)

        # Parse and deduplicate
        parsed_proxies = []
        for proxy_str in set(all_proxies):
            try:
                ip, port = proxy_str.split(":")
                
                # Skip banned IPs
                if ip in self.banlist:
                    continue
                
                proxy = ProxyInfo(
                    ip=ip,
                    port=int(port),
                    protocol="http",
                    country="Unknown",
                    anonymity="Unknown",
                    last_checked=datetime.now()
                )
                parsed_proxies.append(proxy)
            except:
                continue

        self.proxies = parsed_proxies
        self.last_refresh = datetime.now()
        logger.info(f"Proxy pool refreshed: {len(self.proxies)} proxies available")

    async def _fetch_source(self, session: aiohttp.ClientSession, url: str) -> List[str]:
        """Fetch proxies from a single source."""
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as response:
                if response.status == 200:
                    text = await response.text()
                    proxies = [line.strip() for line in text.split('\n') if line.strip()]
                    logger.debug(f"Fetched {len(proxies)} proxies from {url}")
                    return proxies
        except Exception as e:
            logger.warning(f"Failed to fetch from {url}: {e}")
        return []

    async def test_proxy(self, proxy: ProxyInfo, test_url: str = "https://httpbin.org/ip") -> bool:
        """Test if a proxy is working."""
        try:
            start_time = datetime.now()
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    test_url,
                    proxy=proxy.url,
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as response:
                    if response.status == 200:
                        duration = (datetime.now() - start_time).total_seconds() * 1000
                        proxy.speed_ms = duration
                        proxy.last_checked = datetime.now()
                        logger.debug(f"Proxy OK: {proxy.url} ({duration:.0f}ms)")
                        return True
        except Exception as e:
            logger.debug(f"Proxy failed {proxy.url} - {e}")
            # Add to banlist if consistently failing
            self.banlist.add(proxy.ip)
        return False

    async def get_working_proxy(self, test_count: int = 5) -> Optional[ProxyInfo]:
        """Get a working proxy from the pool."""
        # Refresh pool if needed
        if (
            not self.last_refresh or
            datetime.now() - self.last_refresh > timedelta(hours=1) or
            len(self.proxies) < self.min_proxies
        ):
            await self.refresh_proxy_pool()

        # Test random sample
        test_proxies = random.sample(self.proxies, min(test_count, len(self.proxies)))
        tasks = [self.test_proxy(proxy) for proxy in test_proxies]
        results = await asyncio.gather(*tasks)

        working_proxies = [proxy for proxy, is_working in zip(test_proxies, results) if is_working]

        if not working_proxies:
            logger.error("No working proxies found, retrying...")
            # Remove tested proxies and retry
            self.proxies = [p for p in self.proxies if p not in test_proxies]
            return await self.get_working_proxy(test_count)

        # Return fastest proxy
        best_proxy = min(working_proxies, key=lambda p: p.speed_ms)
        logger.info(f"Selected proxy: {best_proxy}")
        return best_proxy

    async def get_proxy_for_request(self) -> Dict[str, str]:
        """Get proxy dict for requests/aiohttp."""
        proxy = await self.get_working_proxy()
        return {
            'http': proxy.url,
            'https': proxy.url
        }


if __name__ == "__main__":
    async def main():
        manager = FreeProxyManager(min_proxies=100)
        proxy = await manager.get_working_proxy()
        print(f"Best proxy: {proxy}")
        
        proxies = await manager.get_proxy_for_request()
        print(f"Proxies for requests: {proxies}")

    asyncio.run(main())
