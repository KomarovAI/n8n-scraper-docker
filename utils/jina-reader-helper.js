// 🔥 JINA AI READER HELPER - ЗАМЕНА FIRECRAWL
// ✅ Бесплатно, в 5 раз быстрее, не требует API key

/**
 * Jina AI Reader - конвертирует любой URL в чистый Markdown
 * Использует ReaderLM-v2 (1.5B AI модель) для извлечения контента
 * 
 * @param {Object} context - N8N execution context (this)
 * @param {string} url - URL для скрапинга
 * @param {Object} options - Опции
 * @returns {Promise<Object>} - { success, data, error, runner, attempts }
 */
async function jinaReaderScrape(context, url, options = {}) {
  const {
    includeImages = false,
    includeLinks = false,
    returnJSON = true,
    timeout = 10000,
    apiKey = null // Опциональный API key для больших лимитов
  } = options;

  try {
    // Построить URL с параметрами
    let jinaUrl = `https://r.jina.ai/${url}`;
    const params = [];
    
    if (includeImages) {
      params.push('x-with-images-summary=true');
    }
    if (includeLinks) {
      params.push('x-with-links-summary=true');
    }
    
    if (params.length > 0) {
      jinaUrl += '?' + params.join('&');
    }

    // Подготовить headers
    const headers = {};
    
    if (returnJSON) {
      headers['Accept'] = 'application/json';
    }
    
    // Добавить API key если есть
    if (apiKey) {
      headers['Authorization'] = `Bearer ${apiKey}`;
    } else if (process.env.JINA_API_KEY) {
      headers['Authorization'] = `Bearer ${process.env.JINA_API_KEY}`;
    }

    // Выполнить запрос
    const response = await context.helpers.httpRequest({
      method: 'GET',
      url: jinaUrl,
      headers,
      timeout
    });

    // Парсинг ответа
    let data;
    if (returnJSON) {
      // JSON ответ
      data = {
        title: response.data?.title || '',
        text_content: response.data?.content || '',
        description: response.data?.description || '',
        url: response.data?.url || url,
        images: response.data?.images || [],
        links: response.data?.links || [],
        meta: {
          text_length: (response.data?.content || '').length,
          images_count: (response.data?.images || []).length,
          links_count: (response.data?.links || []).length
        }
      };
    } else {
      // Markdown ответ (простой текст)
      const content = typeof response === 'string' ? response : response.data;
      data = {
        title: extractTitleFromMarkdown(content),
        text_content: content,
        meta: {
          text_length: content.length
        }
      };
    }

    return {
      url,
      success: true,
      runner: 'jina_ai_reader',
      data,
      timestamp: new Date().toISOString(),
      attempts: 1
    };

  } catch (error) {
    return {
      url,
      success: false,
      error: error.message,
      runner: 'jina_ai_reader',
      timestamp: new Date().toISOString(),
      attempts: 1
    };
  }
}

/**
 * Jina AI Reader с retry логикой
 * @param {Object} context - N8N execution context
 * @param {string} url - URL для скрапинга
 * @param {number} maxRetries - Максимальное количество попыток
 * @param {Object} options - Опции
 * @returns {Promise<Object>}
 */
async function jinaReaderWithRetry(context, url, maxRetries = 3, options = {}) {
  let lastError = null;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const result = await jinaReaderScrape(context, url, options);
      
      if (result.success) {
        result.attempts = attempt + 1;
        return result;
      }
      
      lastError = result.error;
      
    } catch (error) {
      lastError = error.message;
    }

    // Exponential backoff перед следующей попыткой
    if (attempt < maxRetries - 1) {
      const delay = 1000 * Math.pow(2, attempt); // 1s, 2s, 4s
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  // Все попытки провалились
  return {
    url,
    success: false,
    error: lastError || 'All retry attempts failed',
    runner: 'jina_ai_reader',
    timestamp: new Date().toISOString(),
    attempts: maxRetries
  };
}

/**
 * Batch scraping с Jina AI Reader
 * Обрабатывает множество URLs последовательно
 * @param {Object} context - N8N execution context
 * @param {Array<string>} urls - Массив URLs
 * @param {Object} options - Опции
 * @returns {Promise<Array>}
 */
async function jinaReaderBatch(context, urls, options = {}) {
  const results = [];
  const { maxRetries = 3, delayBetweenRequests = 100 } = options;

  for (const url of urls) {
    const result = await jinaReaderWithRetry(context, url, maxRetries, options);
    results.push(result);

    // Небольшая задержка между запросами (политность к Jina)
    if (delayBetweenRequests > 0 && urls.indexOf(url) < urls.length - 1) {
      await new Promise(resolve => setTimeout(resolve, delayBetweenRequests));
    }
  }

  return results;
}

/**
 * Извлечь заголовок из markdown текста
 */
function extractTitleFromMarkdown(markdown) {
  const titleMatch = markdown.match(/^#\s+(.+)$/m);
  if (titleMatch) {
    return titleMatch[1].trim();
  }
  
  // Попытаться найти Title: ... в метаданных
  const metaTitleMatch = markdown.match(/Title:\s*(.+)/i);
  if (metaTitleMatch) {
    return metaTitleMatch[1].trim();
  }
  
  return '';
}

/**
 * Проверка доступности Jina AI Reader
 */
async function isJinaAvailable(context) {
  try {
    const response = await context.helpers.httpRequest({
      method: 'GET',
      url: 'https://r.jina.ai/https://example.com',
      timeout: 5000,
      headers: {
        'Accept': 'text/plain'
      }
    });
    
    return response && response.length > 0;
  } catch (error) {
    console.error('Jina AI Reader unavailable:', error.message);
    return false;
  }
}

/**
 * Статистика по rate limits
 * Без API key: 20 req/min
 * С бесплатным API key: 500 req/min
 */
function getRateLimitInfo(hasApiKey) {
  return {
    requestsPerMinute: hasApiKey ? 500 : 20,
    recommendedDelay: hasApiKey ? 120 : 3000, // ms between requests
    monthlyLimit: hasApiKey ? 10000000 : null, // tokens
    cost: 0 // FREE!
  };
}

module.exports = {
  jinaReaderScrape,
  jinaReaderWithRetry,
  jinaReaderBatch,
  isJinaAvailable,
  getRateLimitInfo,
  extractTitleFromMarkdown
};
