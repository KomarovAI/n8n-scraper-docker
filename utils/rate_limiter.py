#!/usr/bin/env python3
"""
Redis-based Adaptive Rate Limiter
Token bucket algorithm with dynamic rate adjustment.
"""

import asyncio
import time
from typing import Optional
from redis import Redis
from loguru import logger


class AdaptiveRateLimiter:
    """
    Adaptive rate limiter using Redis and token bucket algorithm.
    Adjusts rate based on server response times and status codes.
    """

    def __init__(
        self,
        redis_client: Redis,
        base_rate: float = 5.0,  # requests per second
        domain: str = "default"
    ):
        self.redis = redis_client
        self.base_rate = base_rate
        self.current_rate = base_rate
        self.domain = domain
        self.key = f"rate_limiter:{domain}"

    async def adjust_rate(self, response_time: float, status_code: int):
        """
        Adjust rate based on server response.
        
        Args:
            response_time: Response time in milliseconds
            status_code: HTTP status code
        """
        if status_code == 429:  # Too Many Requests
            self.current_rate *= 0.5
            logger.warning(f"Rate reduced to {self.current_rate} req/s due to 429")
        
        elif response_time > 5000:  # Slow response (>5s)
            self.current_rate *= 0.8
            logger.info(f"Rate reduced to {self.current_rate} req/s due to slow response")
        
        elif response_time < 500 and status_code == 200:  # Fast successful response
            # Gradually increase rate up to 2x base rate
            self.current_rate = min(self.current_rate * 1.1, self.base_rate * 2)
            logger.debug(f"Rate increased to {self.current_rate} req/s")
        
        # Store current rate in Redis with 5 min expiry
        await self._store_rate()

    async def _store_rate(self):
        """Store current rate in Redis."""
        try:
            self.redis.setex(self.key, 300, str(self.current_rate))
        except Exception as e:
            logger.error(f"Failed to store rate in Redis: {e}")

    async def _load_rate(self) -> Optional[float]:
        """Load rate from Redis."""
        try:
            rate = self.redis.get(self.key)
            if rate:
                return float(rate.decode())
        except Exception as e:
            logger.error(f"Failed to load rate from Redis: {e}")
        return None

    async def acquire(self, tokens: int = 1) -> bool:
        """
        Acquire tokens from the bucket.
        
        Args:
            tokens: Number of tokens to acquire (default: 1)
            
        Returns:
            bool: True if tokens acquired, False if rate limited
        """
        # Load current rate from Redis if available
        stored_rate = await self._load_rate()
        if stored_rate:
            self.current_rate = stored_rate

        # Token bucket implementation
        now = time.time()
        bucket_key = f"{self.key}:bucket"
        last_update_key = f"{self.key}:last_update"

        try:
            # Get current bucket state
            current_tokens = self.redis.get(bucket_key)
            last_update = self.redis.get(last_update_key)

            if current_tokens is None:
                current_tokens = self.current_rate
            else:
                current_tokens = float(current_tokens.decode())

            if last_update is None:
                last_update = now
            else:
                last_update = float(last_update.decode())

            # Refill tokens based on time elapsed
            time_elapsed = now - last_update
            refill_tokens = time_elapsed * self.current_rate
            current_tokens = min(current_tokens + refill_tokens, self.current_rate)

            # Try to consume tokens
            if current_tokens >= tokens:
                current_tokens -= tokens
                
                # Update Redis
                pipe = self.redis.pipeline()
                pipe.setex(bucket_key, 60, str(current_tokens))
                pipe.setex(last_update_key, 60, str(now))
                pipe.execute()
                
                return True
            else:
                logger.warning(f"Rate limit reached for {self.domain}")
                return False

        except Exception as e:
            logger.error(f"Rate limiter error: {e}")
            # Fail open - allow request if Redis is down
            return True

    async def wait_for_token(self, tokens: int = 1, max_wait: float = 30.0):
        """
        Wait until a token is available.
        
        Args:
            tokens: Number of tokens needed
            max_wait: Maximum time to wait in seconds
        """
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            if await self.acquire(tokens):
                return True
            
            # Calculate sleep time based on current rate
            sleep_time = tokens / self.current_rate
            await asyncio.sleep(sleep_time)
        
        logger.error(f"Timeout waiting for rate limiter token after {max_wait}s")
        return False

    def get_current_rate(self) -> float:
        """Get current rate limit."""
        return self.current_rate

    def reset_rate(self):
        """Reset rate to base rate."""
        self.current_rate = self.base_rate
        logger.info(f"Rate reset to base rate: {self.base_rate} req/s")


if __name__ == "__main__":
    # Example usage
    async def main():
        redis_client = Redis(host='localhost', port=6379, decode_responses=False)
        limiter = AdaptiveRateLimiter(redis_client, base_rate=5.0, domain="example.com")

        # Simulate requests
        for i in range(10):
            if await limiter.acquire():
                print(f"Request {i+1} allowed - Rate: {limiter.get_current_rate():.2f} req/s")
                
                # Simulate response
                response_time = 200 + i * 100  # Gradually slower
                status_code = 200
                await limiter.adjust_rate(response_time, status_code)
            else:
                print(f"Request {i+1} rate limited")
                await limiter.wait_for_token()
            
            await asyncio.sleep(0.1)

    asyncio.run(main())
