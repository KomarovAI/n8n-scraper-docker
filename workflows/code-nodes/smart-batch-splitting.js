// smart-batch-splitting.js
// Умное разделение на батчи с рандомными задержками для защиты от банов/детекта

const MAX_CONCURRENT_TABS = parseInt(process.env.MAX_CONCURRENT_TABS) || 5;  // не больше 5 табов сразу
const DELAY_BETWEEN_BATCHES = parseInt(process.env.DELAY_BETWEEN_BATCHES) || 3000; // 3 сек между батчами
const DELAY_BETWEEN_REQUESTS = parseInt(process.env.DELAY_BETWEEN_REQUESTS) || 500; // 0.5 сек между запросами
const RANDOMIZE_DELAYS = process.env.RANDOMIZE_DELAYS === 'true';

function calculateDelay(baseDelay, randomize = false) {
  if (!randomize) return baseDelay;
  const variance = 0.3;
  const min = baseDelay * (1 - variance);
  const max = baseDelay * (1 + variance);
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

const urls = Array.isArray($json.urls) ? $json.urls : [$json.url];
const batches = [];

for (let i = 0; i < urls.length; i += MAX_CONCURRENT_TABS) {
  const batchNum = Math.floor(i / MAX_CONCURRENT_TABS);
  batches.push({
    batchId: batchNum + 1,
    urls: urls.slice(i, i + MAX_CONCURRENT_TABS),
    delay: calculateDelay(DELAY_BETWEEN_BATCHES * batchNum, RANDOMIZE_DELAYS)
  });
}

return batches.map(batch => ({ json: batch }));
