// ✅ FIX #3: Native HTTP request without axios
// ✅ FIX #4: Native HTML parsing without cheerio  
// ✅ FIX #5: Firecrawl API key validation
// ✅ FIX #6: Enhanced quality check with spam detection

/**
 * ✅ FIX #3: HTTP Request using n8n's built-in helper
 * Replaces axios dependency
 */
async function httpRequestN8n(context, url, options = {}) {
  try {
    const response = await context.helpers.httpRequest({
      method: options.method || 'GET',
      url,
      timeout: options.timeout || 30000,
      headers: {
        'User-Agent': options.userAgent || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        ...options.headers
      },
      ...options
    });

    return {
      success: true,
      data: response,
      statusCode: response.statusCode || 200,
      error: null
    };
  } catch (error) {
    return {
      success: false,
      data: null,
      statusCode: error.statusCode || 500,
      error: error.message
    };
  }
}

/**
 * ✅ FIX #4: Native HTML parsing without cheerio
 * Extracts title, content, and links from HTML
 */
function parseHTMLNative(html) {
  try {
    // Extract title
    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
    const title = titleMatch ? titleMatch[1].trim() : '';

    // Extract meta description
    const descMatch = html.match(/<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["']/i);
    const description = descMatch ? descMatch[1] : '';

    // Remove scripts and styles
    let cleanHTML = html
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
      .replace(/<!--[\s\S]*?-->/g, '');

    // Extract body content
    const bodyMatch = cleanHTML.match(/<body[^>]*>([\s\S]*)<\/body>/i);
    const bodyHTML = bodyMatch ? bodyMatch[1] : cleanHTML;

    // Priority-based content extraction
    const mainMatch = bodyHTML.match(/<main[^>]*>([\s\S]*?)<\/main>/i);
    const articleMatch = bodyHTML.match(/<article[^>]*>([\s\S]*?)<\/article>/i);
    const contentMatch = bodyHTML.match(/<(div|section)[^>]*(?:class|id)=["'][^"']*content[^"']*["'][^>]*>([\s\S]*?)<\/\1>/i);

    let mainContent = mainMatch ? mainMatch[1] :
                      articleMatch ? articleMatch[1] :
                      contentMatch ? contentMatch[2] :
                      bodyHTML;

    // Strip all HTML tags
    const textContent = mainContent
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ')
      .trim()
      .substring(0, 50000);

    // Extract links (simple regex approach)
    const links = [];
    const linkRegex = /<a[^>]*href=["']([^"'#][^"']*)["'][^>]*>([^<]*)<\/a>/gi;
    let match;
    let linkCount = 0;

    while ((match = linkRegex.exec(bodyHTML)) !== null && linkCount < 100) {
      links.push({
        url: match[1],
        text: match[2].replace(/<[^>]+>/g, '').trim()
      });
      linkCount++;
    }

    return {
      title,
      description,
      text_content: textContent,
      links,
      meta: {
        text_length: textContent.length,
        links_count: links.length
      }
    };
  } catch (error) {
    throw new Error(`HTML parsing failed: ${error.message}`);
  }
}

/**
 * ✅ FIX #5: Validate Firecrawl API key before usage
 */
function validateFirecrawlAPIKey(context) {
  // Try to get from credentials first
  let apiKey = null;

  try {
    const credentials = context.getCredentials('firecrawl');
    apiKey = credentials?.apiKey;
  } catch (error) {
    // Credentials not configured, try env var
  }

  if (!apiKey) {
    apiKey = process.env.FIRECRAWL_API_KEY;
  }

  if (!apiKey) {
    return {
      valid: false,
      error: 'Firecrawl API key not configured. Set FIRECRAWL_API_KEY env var or configure credentials.'
    };
  }

  if (apiKey.length < 20) {
    return {
      valid: false,
      error: 'Firecrawl API key appears invalid (too short)'
    };
  }

  return {
    valid: true,
    apiKey
  };
}

/**
 * ✅ FIX #6: Enhanced quality check with spam detection
 * Minimum 500 chars, checks for repetitive patterns
 */
function isQualityContent(data) {
  const text = data?.text_content || '';
  const length = text.length;

  // Minimum 500 characters
  if (length < 500) {
    return {
      passed: false,
      reason: `Content too short (${length} chars, minimum 500)`
    };
  }

  // Check for unique characters (spam detection)
  const uniqueChars = new Set(text.toLowerCase()).size;
  if (uniqueChars < 20) {
    return {
      passed: false,
      reason: `Too repetitive (only ${uniqueChars} unique characters)`
    };
  }

  // Check word count
  const words = text.split(/\s+/).filter(w => w.length > 2);
  if (words.length < 50) {
    return {
      passed: false,
      reason: `Too few words (${words.length}, minimum 50)`
    };
  }

  // Check for repetitive words (spam)
  const wordCounts = {};
  for (const word of words) {
    const lower = word.toLowerCase();
    wordCounts[lower] = (wordCounts[lower] || 0) + 1;
  }

  const maxWordFrequency = Math.max(...Object.values(wordCounts));
  const repetitionRatio = maxWordFrequency / words.length;

  if (repetitionRatio > 0.3) {
    return {
      passed: false,
      reason: `Spam detected: one word repeated ${(repetitionRatio * 100).toFixed(1)}% of the time`
    };
  }

  // Check for common spam patterns
  const spamPatterns = [
    /click here/gi,
    /buy now/gi,
    /limited offer/gi,
    /(viagra|cialis|lottery|casino)/gi
  ];

  for (const pattern of spamPatterns) {
    const matches = text.match(pattern);
    if (matches && matches.length > 5) {
      return {
        passed: false,
        reason: `Spam pattern detected: ${pattern.source}`
      };
    }
  }

  return {
    passed: true,
    metrics: {
      length,
      uniqueChars,
      wordCount: words.length,
      repetitionRatio: (repetitionRatio * 100).toFixed(2) + '%'
    }
  };
}

/**
 * Circuit Breaker implementation
 */
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 60000; // 60 seconds
    this.monitoringPeriod = options.monitoringPeriod || 10000; // 10 seconds
    
    this.failures = 0;
    this.lastFailureTime = null;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
  }

  async execute(fn, fallback) {
    if (this.state === 'OPEN') {
      const timeSinceLastFailure = Date.now() - this.lastFailureTime;
      
      if (timeSinceLastFailure > this.resetTimeout) {
        this.state = 'HALF_OPEN';
        this.failures = 0;
      } else {
        console.warn(`Circuit breaker OPEN, using fallback`);
        return fallback ? await fallback() : null;
      }
    }

    try {
      const result = await fn();
      
      if (this.state === 'HALF_OPEN') {
        this.state = 'CLOSED';
        this.failures = 0;
      }
      
      return result;
    } catch (error) {
      this.failures++;
      this.lastFailureTime = Date.now();

      if (this.failures >= this.failureThreshold) {
        this.state = 'OPEN';
        console.error(`Circuit breaker tripped after ${this.failures} failures`);
      }

      if (fallback) {
        return await fallback();
      }
      
      throw error;
    }
  }

  getState() {
    return {
      state: this.state,
      failures: this.failures,
      lastFailureTime: this.lastFailureTime
    };
  }

  reset() {
    this.state = 'CLOSED';
    this.failures = 0;
    this.lastFailureTime = null;
  }
}

module.exports = {
  httpRequestN8n,
  parseHTMLNative,
  validateFirecrawlAPIKey,
  isQualityContent,
  CircuitBreaker
};
