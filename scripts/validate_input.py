#!/usr/bin/env python3
"""
Secure input validation for GitHub Actions workflows
Prevents script injection and SSRF attacks
"""

import json
import os
import sys
from typing import List, Dict
from urllib.parse import urlparse
from pydantic import BaseModel, HttpUrl, validator, Field
import re


class URLData(BaseModel):
    """Validated URL data model"""
    url: HttpUrl
    selector: str = Field(default='main, article, .content, body', max_length=500)
    waitFor: str = Field(default='', max_length=500)
    extractImages: bool = False
    
    @validator('url')
    def validate_url_security(cls, v):
        """SSRF protection"""
        parsed = urlparse(str(v))
        
        # Block non-HTTP(S) schemes
        if parsed.scheme not in ['http', 'https']:
            raise ValueError(f'Invalid scheme: {parsed.scheme}')
        
        # Block localhost and loopback
        blocked_hosts = [
            'localhost', '127.0.0.1', '0.0.0.0',
            '::1', '0000:0000:0000:0000:0000:0000:0000:0001',
            # Cloud metadata endpoints
            '169.254.169.254', 'metadata.google.internal',
            'metadata.azure.com', 'instance-data',
        ]
        
        hostname = parsed.hostname or ''
        if any(blocked in hostname.lower() for blocked in blocked_hosts):
            raise ValueError(f'Blocked host: {hostname}')
        
        # Block private IP ranges
        if (hostname.startswith('10.') or 
            hostname.startswith('172.16.') or 
            hostname.startswith('192.168.')):
            raise ValueError(f'Private IP not allowed: {hostname}')
        
        return v
    
    @validator('selector', 'waitFor')
    def validate_selector(cls, v):
        """Prevent selector injection"""
        # Allow only safe CSS selectors
        if re.search(r'[<>"\';\\]', v):
            raise ValueError('Invalid characters in selector')
        return v


class BatchInput(BaseModel):
    """Batch input validation"""
    urls: List[URLData] = Field(max_items=100)
    batchId: str = Field(regex=r'^[a-zA-Z0-9_-]+$', max_length=100)


def main():
    """Validate and sanitize input from environment"""
    try:
        # Read from environment (safe from injection)
        urls_json = os.getenv('URLS_JSON', '[]')
        batch_id = os.getenv('BATCH_ID', 'unknown')
        
        # Parse JSON
        urls_data = json.loads(urls_json)
        
        # Validate with Pydantic
        batch = BatchInput(
            urls=urls_data,
            batchId=batch_id
        )
        
        # Save validated data to secure location
        validated = {
            'urls': [url.dict() for url in batch.urls],
            'batchId': batch.batchId,
            'total': len(batch.urls)
        }
        
        with open('/tmp/validated_urls.json', 'w') as f:
            json.dump(validated, f)
        
        print(f'✓ Validated {len(batch.urls)} URLs for batch {batch.batchId}')
        sys.exit(0)
        
    except json.JSONDecodeError as e:
        print(f'✗ Invalid JSON: {e}', file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f'✗ Validation failed: {e}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
