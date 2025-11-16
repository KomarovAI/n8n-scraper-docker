#!/usr/bin/env node
/**
 * Secure input validation for Playwright workflows
 * Prevents script injection and SSRF attacks
 */

const fs = require('fs');

class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

function validateUrl(url) {
  try {
    const parsed = new URL(url);
    
    // Block non-HTTP(S) schemes
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      throw new ValidationError(`Invalid scheme: ${parsed.protocol}`);
    }
    
    // SSRF protection - blocked hosts
    const blockedHosts = [
      'localhost', '127.0.0.1', '0.0.0.0',
      '::1', '0000:0000:0000:0000:0000:0000:0000:0001',
      '169.254.169.254', 'metadata.google.internal',
      'metadata.azure.com', 'instance-data'
    ];
    
    const hostname = parsed.hostname.toLowerCase();
    if (blockedHosts.some(blocked => hostname.includes(blocked))) {
      throw new ValidationError(`Blocked host: ${hostname}`);
    }
    
    // Block private IP ranges
    if (hostname.startsWith('10.') ||
        hostname.startsWith('172.16.') ||
        hostname.startsWith('192.168.') ||
        hostname.startsWith('fd') || // IPv6 ULA
        hostname.startsWith('fe80:')) { // IPv6 link-local
      throw new ValidationError(`Private IP not allowed: ${hostname}`);
    }
    
    return true;
  } catch (error) {
    if (error instanceof ValidationError) throw error;
    throw new ValidationError(`Invalid URL: ${error.message}`);
  }
}

function validateSelector(selector) {
  // Prevent selector injection
  if (/[<>"';\\]/.test(selector)) {
    throw new ValidationError('Invalid characters in selector');
  }
  if (selector.length > 500) {
    throw new ValidationError('Selector too long');
  }
  return true;
}

function main() {
  try {
    // Read from environment (safe from injection)
    const urlsJson = process.env.URLS_JSON || '[]';
    const batchId = process.env.BATCH_ID || 'unknown';
    
    // Validate batchId
    if (!/^[a-zA-Z0-9_-]+$/.test(batchId) || batchId.length > 100) {
      throw new ValidationError('Invalid batch ID');
    }
    
    // Parse JSON
    let urlsData;
    try {
      urlsData = JSON.parse(urlsJson);
    } catch (e) {
      throw new ValidationError(`Invalid JSON: ${e.message}`);
    }
    
    if (!Array.isArray(urlsData)) {
      throw new ValidationError('URLs must be an array');
    }
    
    if (urlsData.length === 0) {
      throw new ValidationError('No URLs provided');
    }
    
    if (urlsData.length > 100) {
      throw new ValidationError(`Too many URLs (${urlsData.length}), max 100 per batch`);
    }
    
    // Validate each URL
    const validated = [];
    for (const item of urlsData) {
      if (!item || typeof item !== 'object') continue;
      if (!item.url) continue;
      
      validateUrl(item.url);
      
      const selector = item.selector || 'main, article, .content, body';
      const waitFor = item.waitFor || '';
      
      validateSelector(selector);
      if (waitFor) validateSelector(waitFor);
      
      validated.push({
        url: item.url,
        selector,
        waitFor,
        extractImages: Boolean(item.extractImages)
      });
    }
    
    if (validated.length === 0) {
      throw new ValidationError('No valid URLs after validation');
    }
    
    // Save validated data
    const output = {
      urls: validated,
      batchId,
      total: validated.length
    };
    
    fs.writeFileSync('/tmp/validated_urls.json', JSON.stringify(output, null, 2));
    
    console.log(`✓ Validated ${validated.length} URLs for batch ${batchId}`);
    process.exit(0);
    
  } catch (error) {
    console.error(`✗ Validation failed: ${error.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { validateUrl, validateSelector };
