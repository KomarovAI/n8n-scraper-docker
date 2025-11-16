#!/usr/bin/env python3
"""
Verify integrity of scraping results before upload
"""

import json
import sys
from pydantic import BaseModel, Field, validator
from typing import List, Dict, Optional


class ScrapedResult(BaseModel):
    """Single scraped result schema"""
    url: str
    success: bool
    title: Optional[str] = None
    text_content: Optional[str] = None
    meta: Dict = {}
    timestamp: str
    runner: str
    execution_time_ms: Optional[int] = None
    error: Optional[str] = None


class ResultsFile(BaseModel):
    """Results file schema"""
    batch_id: str
    successful: List[ScrapedResult] = []
    failed: List[Dict] = []
    stats: Dict
    timestamp: str
    
    @validator('successful')
    def validate_successful(cls, v):
        if not isinstance(v, list):
            raise ValueError('successful must be list')
        return v


def main():
    """Verify results file integrity"""
    try:
        with open('results.json', 'r') as f:
            data = json.load(f)
        
        # Validate schema
        results = ResultsFile(**data)
        
        # Additional checks
        if results.stats.get('total', 0) != len(results.successful) + len(results.failed):
            print('⚠ Warning: Stats mismatch', file=sys.stderr)
        
        print(f'✓ Results verified: {len(results.successful)} successful, {len(results.failed)} failed')
        sys.exit(0)
        
    except FileNotFoundError:
        print('✗ results.json not found', file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f'✗ Invalid JSON: {e}', file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f'✗ Verification failed: {e}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
