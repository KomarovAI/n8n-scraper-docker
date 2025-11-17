// 🔥 HYBRID FALLBACK: FIRECRAWL + JINA AI READER
// 🎯 Стратегия: каждый 3-й URL через Firecrawl (пока есть токены), остальные через Jina
// 💰 Экономия: используем дорогой Firecrawl только для 33% запросов
// ⚡ Скорость: 66% запросов идут через быстрый Jina (3-5s vs 10-30s)
//
// Вставьте этот код в N8N Code Node "Hybrid Fallback"

const failedItems = $input.all().filter(item => 
  !item.json.success || (item.json.data?.text_length || 0) < 500
);

if (failedItems.length === 0) {
  return [];
}

const results = [];
const MAX_RETRIES = 3;

// Проверяем наличие API ключей
const FIRECRAWL_API_KEY = process.env.FIRECRAWL_API_KEY || null;
const JINA_API_KEY = process.env.JINA_API_KEY || null;

const hasFirecrawl = FIRECRAWL_API_KEY !== null;
const hasJina = JINA_API_KEY !== null;

console.log(`🔥 Hybrid Fallback: processing ${failedItems.length} failed items`);
console.log(`✅ Firecrawl API: ${hasFirecrawl ? 'Available' : 'Not configured'}`);
console.log(`✅ Jina API key: ${hasJina ? 'Available (500 req/min)' : 'Using free tier (20 req/min)'}`);

/**
 * Firecrawl scraper with retry
 */
async function retryFirecrawl(url, retries = MAX_RETRIES) {
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const response = await this.helpers.httpRequest({
        method: 'POST',
        url: 'https://api.firecrawl.dev/v1/scrape',
        headers: {
          'Authorization': `Bearer ${FIRECRAWL_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: {
          url,
          formats: ['markdown', 'html'],
          onlyMainContent: true
        },
        timeout: 30000  // 30 seconds for Firecrawl
      });

      const data = typeof response === 'string' ? JSON.parse(response) : response;
      const textContent = data.data?.markdown || data.markdown || '';

      return {
        url,
        success: true,
        runner: 'firecrawl',
        data: {
          title: data.data?.title || data.title || '',
          description: data.data?.description || data.description || '',
          text_content: textContent,
          meta: {
            text_length: textContent.length,
            source: 'firecrawl',
            cost_estimate: 0.003  // $0.003 per request
          }
        },
        timestamp: new Date().toISOString(),
        attempts: attempt + 1
      };
    } catch (error) {
      console.warn(`Firecrawl attempt ${attempt + 1} failed for ${url}: ${error.message}`);
      
      // Если закончились токены - переключаемся на Jina
      if (error.message.includes('quota') || error.message.includes('limit')) {
        console.warn(`⚠️ Firecrawl quota exceeded, falling back to Jina for ${url}`);
        return await retryJinaReader(url, MAX_RETRIES);
      }
      
      if (attempt === retries - 1) {
        console.error(`❌ Firecrawl failed after ${retries} attempts, falling back to Jina`);
        return await retryJinaReader(url, MAX_RETRIES);
      }
      
      await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt)));
    }
  }
}

/**
 * Jina AI Reader scraper with retry
 */
async function retryJinaReader(url, retries = MAX_RETRIES) {
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const jinaUrl = `https://r.jina.ai/${url}`;
      const headers = { 'Accept': 'application/json' };
      
      if (JINA_API_KEY) {
        headers['Authorization'] = `Bearer ${JINA_API_KEY}`;
      }

      const response = await this.helpers.httpRequest({
        method: 'GET',
        url: jinaUrl,
        headers,
        timeout: 10000  // 10 seconds for Jina (3x faster!)
      });

      const data = typeof response === 'string' ? JSON.parse(response) : response;
      const textContent = data.content || data.data?.content || '';

      return {
        url,
        success: true,
        runner: 'jina_ai_reader',
        data: {
          title: data.title || data.data?.title || '',
          description: data.description || data.data?.description || '',
          text_content: textContent,
          meta: {
            text_length: textContent.length,
            source: 'jina_ai_reader',
            cost_estimate: 0  // FREE!
          }
        },
        timestamp: new Date().toISOString(),
        attempts: attempt + 1
      };
    } catch (error) {
      console.warn(`Jina attempt ${attempt + 1} failed for ${url}: ${error.message}`);
      
      if (attempt === retries - 1) {
        return {
          url,
          success: false,
          error: `Both Firecrawl and Jina failed: ${error.message}`,
          runner: 'jina_ai_reader',
          attempts: attempt + 1
        };
      }
      
      await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt)));
    }
  }
}

// Обрабатываем каждый URL с умной стратегией
let firecrawlCount = 0;
let jinaCount = 0;

for (let i = 0; i < failedItems.length; i++) {
  const url = failedItems[i].json.url;
  let result;

  // 🎯 СТРАТЕГИЯ: каждый 3-й URL через Firecrawl (если есть API key)
  // Примеры: i=0→Jina, i=1→Jina, i=2→Firecrawl, i=3→Jina, i=4→Jina, i=5→Firecrawl...
  if (hasFirecrawl && (i % 3 === 2)) {
    console.log(`🔥 [${i+1}/${failedItems.length}] Using Firecrawl for ${url}`);
    result = await retryFirecrawl(url, MAX_RETRIES);
    firecrawlCount++;
  } else {
    console.log(`⚡ [${i+1}/${failedItems.length}] Using Jina AI Reader for ${url}`);
    result = await retryJinaReader(url, MAX_RETRIES);
    jinaCount++;
  }
  
  results.push(result);
  
  // Politeness delay
  if (i < failedItems.length - 1) {
    await new Promise(resolve => setTimeout(resolve, 200));
  }
}

// Статистика
const successful = results.filter(r => r.success).length;
const failed = results.filter(r => !r.success).length;
const totalCost = firecrawlCount * 0.003;  // $0.003 per Firecrawl request

console.log('');
console.log('📊 HYBRID FALLBACK STATISTICS:');
console.log(`   Total processed: ${failedItems.length}`);
console.log(`   ✅ Successful: ${successful}`);
console.log(`   ❌ Failed: ${failed}`);
console.log('');
console.log('🎯 RUNNER DISTRIBUTION:');
console.log(`   🔥 Firecrawl: ${firecrawlCount} requests (${((firecrawlCount/failedItems.length)*100).toFixed(1)}%)`);
console.log(`   ⚡ Jina AI: ${jinaCount} requests (${((jinaCount/failedItems.length)*100).toFixed(1)}%)`);
console.log('');
console.log('💰 COST ANALYSIS:');
console.log(`   Firecrawl cost: $${totalCost.toFixed(4)}`);
console.log(`   Jina cost: $0.00 (FREE)`);
console.log(`   Total cost: $${totalCost.toFixed(4)}`);
console.log(`   vs Full Firecrawl: $${(failedItems.length * 0.003).toFixed(4)} (saved ${(((1 - totalCost/(failedItems.length * 0.003))*100).toFixed(1))}%)`);

return results.map(r => ({ json: r }));
