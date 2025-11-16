#!/usr/bin/env python3
"""
TOR Proxy Manager
Provides TOR network integration for anonymous web scraping.
"""

import asyncio
import requests
from stem import Signal
from stem.control import Controller
from loguru import logger
from typing import Optional
import time


class TORProxyManager:
    """
    TOR Proxy Manager for anonymous requests.
    Manages TOR circuit renewal and provides SOCKS5 proxy interface.
    """

    def __init__(
        self,
        control_host: str = "localhost",
        control_port: int = 9051,
        socks_host: str = "localhost",
        socks_port: int = 9050,
        control_password: Optional[str] = None
    ):
        self.control_host = control_host
        self.control_port = control_port
        self.socks_host = socks_host
        self.socks_port = socks_port
        self.control_password = control_password
        self.session = None
        self._init_session()

    def _init_session(self):
        """Initialize requests session with TOR proxy."""
        self.session = requests.Session()
        self.session.proxies = {
            'http': f'socks5h://{self.socks_host}:{self.socks_port}',
            'https': f'socks5h://{self.socks_host}:{self.socks_port}'
        }
        logger.info(f"TOR proxy initialized: socks5h://{self.socks_host}:{self.socks_port}")

    def renew_identity(self) -> bool:
        """
        Renew TOR identity to get a new exit node.
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            with Controller.from_port(
                address=self.control_host,
                port=self.control_port
            ) as controller:
                # Authenticate
                if self.control_password:
                    controller.authenticate(password=self.control_password)
                else:
                    controller.authenticate()
                
                # Send NEWNYM signal to get new circuit
                controller.signal(Signal.NEWNYM)
                logger.info("TOR identity renewed - new exit node assigned")
                
                # Wait for circuit to establish
                time.sleep(2)
                return True
                
        except Exception as e:
            logger.error(f"Failed to renew TOR identity: {e}")
            return False

    def get_current_ip(self) -> Optional[str]:
        """
        Get current exit node IP address.
        
        Returns:
            str: Current IP address or None if failed
        """
        try:
            response = self.session.get('https://httpbin.org/ip', timeout=10)
            if response.status_code == 200:
                ip = response.json().get('origin')
                logger.info(f"Current TOR exit IP: {ip}")
                return ip
        except Exception as e:
            logger.error(f"Failed to get current IP: {e}")
        return None

    def fetch(self, url: str, **kwargs) -> Optional[requests.Response]:
        """
        Fetch URL through TOR network.
        
        Args:
            url: URL to fetch
            **kwargs: Additional arguments for requests.get()
            
        Returns:
            Response object or None if failed
        """
        try:
            response = self.session.get(url, timeout=30, **kwargs)
            logger.info(f"Fetched {url} via TOR - Status: {response.status_code}")
            return response
        except Exception as e:
            logger.error(f"Failed to fetch {url} via TOR: {e}")
            return None

    async def fetch_async(self, url: str, **kwargs) -> Optional[dict]:
        """
        Async wrapper for fetch method.
        
        Args:
            url: URL to fetch
            **kwargs: Additional arguments
            
        Returns:
            Response data or None
        """
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(None, self.fetch, url)
        
        if response and response.status_code == 200:
            return {
                'url': url,
                'status': response.status_code,
                'content': response.text,
                'headers': dict(response.headers)
            }
        return None

    def close(self):
        """Close the session."""
        if self.session:
            self.session.close()
            logger.info("TOR session closed")


if __name__ == "__main__":
    # Example usage
    tor = TORProxyManager()
    
    # Get current IP
    print(f"Current IP: {tor.get_current_ip()}")
    
    # Renew identity
    tor.renew_identity()
    
    # Get new IP
    print(f"New IP: {tor.get_current_ip()}")
    
    # Fetch a URL
    response = tor.fetch("https://httpbin.org/ip")
    if response:
        print(response.json())
    
    tor.close()
