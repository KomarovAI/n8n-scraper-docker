#!/usr/bin/env python3
"""
Unit tests for input validation
"""

import pytest
from unittest.mock import patch
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from validate_input import URLData, BatchInput, ValidationError
from pydantic import ValidationError as PydanticValidationError


class TestURLValidation:
    """Test URL validation and SSRF protection"""
    
    def test_valid_https_url(self):
        """Valid HTTPS URL should pass"""
        url_data = URLData(url='https://example.com')
        assert str(url_data.url) == 'https://example.com/'
    
    def test_valid_http_url(self):
        """Valid HTTP URL should pass"""
        url_data = URLData(url='http://example.com')
        assert str(url_data.url) == 'http://example.com/'
    
    def test_blocked_localhost(self):
        """Localhost should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(url='http://localhost:8080')
    
    def test_blocked_127001(self):
        """127.0.0.1 should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(url='http://127.0.0.1')
    
    def test_blocked_private_ip_10(self):
        """Private IP 10.x should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(url='http://10.0.0.1')
    
    def test_blocked_private_ip_192(self):
        """Private IP 192.168.x should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(url='http://192.168.1.1')
    
    def test_blocked_aws_metadata(self):
        """AWS metadata endpoint should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(url='http://169.254.169.254/latest/meta-data')
    
    def test_blocked_gcp_metadata(self):
        """GCP metadata endpoint should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(url='http://metadata.google.internal')
    
    def test_invalid_scheme_ftp(self):
        """FTP scheme should be rejected"""
        with pytest.raises(PydanticValidationError):
            URLData(url='ftp://example.com')
    
    def test_invalid_scheme_file(self):
        """File scheme should be rejected"""
        with pytest.raises(PydanticValidationError):
            URLData(url='file:///etc/passwd')


class TestSelectorValidation:
    """Test CSS selector validation"""
    
    def test_valid_selector(self):
        """Valid CSS selector should pass"""
        url_data = URLData(
            url='https://example.com',
            selector='div.class#id'
        )
        assert url_data.selector == 'div.class#id'
    
    def test_blocked_selector_with_quotes(self):
        """Selector with quotes should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(
                url='https://example.com',
                selector='div"><script>alert(1)</script>'
            )
    
    def test_blocked_selector_with_semicolon(self):
        """Selector with semicolon should be blocked"""
        with pytest.raises(PydanticValidationError):
            URLData(
                url='https://example.com',
                selector='div; DROP TABLE users;'
            )


class TestBatchValidation:
    """Test batch input validation"""
    
    def test_valid_batch(self):
        """Valid batch should pass"""
        batch = BatchInput(
            urls=[{'url': 'https://example.com'}],
            batchId='test-123'
        )
        assert len(batch.urls) == 1
        assert batch.batchId == 'test-123'
    
    def test_batch_max_urls(self):
        """Batch with >100 URLs should be rejected"""
        urls = [{'url': f'https://example{i}.com'} for i in range(101)]
        with pytest.raises(PydanticValidationError):
            BatchInput(urls=urls, batchId='test')
    
    def test_invalid_batch_id(self):
        """Batch ID with invalid characters should be rejected"""
        with pytest.raises(PydanticValidationError):
            BatchInput(
                urls=[{'url': 'https://example.com'}],
                batchId='test; rm -rf /'
            )
