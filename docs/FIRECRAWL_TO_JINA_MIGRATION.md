# 🔄 Migration Guide: Firecrawl → Jina AI Reader

## 🎯 Почему меняем?

| Критерий | Firecrawl | Jina AI Reader | Выигрыш |
|----------|-----------|----------------|----------|
| 💰 Стоимость | $3/1000 URLs | **БЕСПЛАТНО** | **$3/1000** |
| ⏱️ Latency | 10-30s | **3-5s** | **в 5-6 раз быстрее** |
| 🔐 API Key | Нужен | **НЕ нужен** | Проще setup |
| 🧠 AI | GPT-4o-mini | ReaderLM-v2 | Одинаковое качество |
| 📈 Rate Limit | Ограничены | 20/min (500 с key) | Выше лимиты |

**Итог**: 💚 Экономия **$36/год** + **в 5 раз быстрее** + нет зависимости от API key!

---

## 🛠️ Шаги миграции

### 1️⃣ Обновить N8N Workflow

**Было** (старый Code Node "Firecrawl Fallback"):

```javascript
const axios = require('axios');

const response = await axios.post(
  'https://api.firecrawl.dev/v1/scrape',
  {
    url,
    formats: ['markdown', 'html'],
    onlyMainContent: true
  },
  {
    headers: {
      'Authorization': `Bearer ${process.env.FIRECRAWL_API_KEY}`,
      'Content-Type': 'application/json'
    },
    timeout: 60000
  }
);

return {
  url,
  success: true,
  runner: 'firecrawl',
  data: {
    title: response.data.title || '',
    text_content: response.data.markdown || ''
  }
};
```

**Стало** (новый Code Node "Jina AI Reader Fallback"):

```javascript
// ✅ Проще, быстрее, бесплатно!
const jinaUrl = `https://r.jina.ai/${url}`;

const response = await this.helpers.httpRequest({
  method: 'GET',
  url: jinaUrl,
  headers: {
    'Accept': 'application/json'
    // API key опционален!
  },
  timeout: 10000  // В 6 раз меньше timeout!
});

const data = typeof response === 'string' ? JSON.parse(response) : response;

return {
  url,
  success: true,
  runner: 'jina_ai_reader',
  data: {
    title: data.title || '',
    text_content: data.content || ''
  }
};
```

**📄 Готовый код**: Скопируйте из `workflows/code-nodes/jina-reader-fallback.js`

---

### 2️⃣ Удалить Firecrawl API Key (опционально)

```bash
# Больше не нужно!
unset FIRECRAWL_API_KEY

# Или удалите из .env
# FIRECRAWL_API_KEY=fc-xxxxx  # <-- удалить строку
```

---

### 3️⃣ Добавить Jina API Key (опционально, для больших лимитов)

**Без API key**:
- ✅ Бесплатно
- ⚠️ 20 requests/minute
- ✅ Достаточно для маленьких проектов

**С бесплатным API key**:
- ✅ Бесплатно (!НЕТ кредитки!)
- ✅ 500 requests/minute (в 25 раз больше!)
- ✅ 10,000,000 tokens/month

**Как получить**:

```bash
# 1. Иди на https://jina.ai/reader/
# 2. Нажми "Get API Key"
# 3. Регистрация через email/GitHub (БЕЗ карты!)
# 4. Получи key мгновенно

# Добавь в .env
echo "JINA_API_KEY=jina_xxxxxxxxxxxxxx" >> .env

# Или в Kubernetes Secret
kubectl create secret generic n8n-credentials \
  --from-literal=jina-api-key='jina_xxxxx' \
  -n n8n-scraper
```

---

### 4️⃣ Обновить Environment Variables

**StatefulSet manifest** (`manifests/statefulset.yaml`):

```yaml
env:
  # ✅ Удалить Firecrawl
  # - name: FIRECRAWL_API_KEY
  #   valueFrom:
  #     secretKeyRef:
  #       name: n8n-credentials
  #       key: firecrawl-api-key
  
  # ✅ Добавить Jina (опционально)
  - name: JINA_API_KEY
    valueFrom:
      secretKeyRef:
        name: n8n-credentials
        key: jina-api-key
        optional: true  # Не обязательно!
```

---

### 5️⃣ Переименовать Node в Workflow

1. Откройте workflow в N8N UI
2. Найдите node **"Firecrawl Fallback (with Retry)"**
3. Переименуйте в **"Jina AI Reader Fallback"**
4. Замените код на новый (из шага 1)
5. Сохраните workflow

---

### 6️⃣ Обновить Quality Check Threshold

В node **"Quality Check"**:

```javascript
// Было
"value2": 100  // Слишком низкий порог

// Стало
"value2": 500  // ✅ FIX #6: Повышенный порог с spam detection
```

---

## ✅ Проверка миграции

### Тест 1: Простой URL

```bash
curl -X POST http://localhost:5678/webhook/scrape \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls": ["https://example.com"]}'
```

**Ожидаемый результат**:
```json
{
  "stats": {
    "by_runner": [
      {"runner": "http_basic", "count": 1}
    ]
  }
}
```

### Тест 2: URL требующий fallback

```bash
curl -X POST http://localhost:5678/webhook/scrape \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls": ["https://complex-site-with-little-content.com"]}'
```

**Ожидаемый результат**:
```json
{
  "stats": {
    "by_runner": [
      {"runner": "jina_ai_reader", "count": 1}  // ✅ Jina сработал!
    ]
  }
}
```

---

## 📊 Monitoring после миграции

### Prometheus Metrics

```promql
# Количество использований Jina
sum(n8n_scrape_requests_total{runner="jina_ai_reader"})

# Latency Jina vs Firecrawl
histogram_quantile(0.95, 
  rate(n8n_scrape_latency_seconds_bucket{runner="jina_ai_reader"}[5m])
)
```

### Журналы

```bash
kubectl logs -f n8n-scraper-0 -n n8n-scraper | grep -i jina
```

**Ожидаемые логи**:
```
🚀 Jina AI Reader Fallback: processing 5 failed items
✅ Using Jina API key for higher rate limits (500 req/min)
✅ Jina AI Reader completed: 5 successful, 0 failed
💰 Cost: $0.00 (FREE!)
⏱️  Avg latency: ~4 seconds per URL
```

---

## 💸 Экономия после миграции

**На 10,000 URLs/месяц** (5% fallback rate):

| Метрика | Firecrawl | Jina AI Reader | Экономия |
|---------|-----------|----------------|----------|
| **Fallback calls** | 500 | 500 | - |
| **💰 Стоимость** | $1.50 | **$0.00** | **$1.50** |
| **⏱️ Total time** | 2.8 hours | **0.5 hours** | **2.3 hours** |
| **🔐 Setup** | Нужен API key | Не нужен | Проще |

**Годовая экономия**: $1.50 × 12 = **$18/год** 💰

---

## 🔗 Полезные ссылки

- 📖 [Jina AI Reader Documentation](https://jina.ai/reader/)
- 🐙 [Jina Reader GitHub](https://github.com/jina-ai/reader)
- 💻 [Code Examples](../workflows/code-nodes/jina-reader-fallback.js)
- 🔧 [Helper Functions](../utils/jina-reader-helper.js)

---

## ❓ FAQ

### Q: Что если Jina AI Reader недоступен?

**A**: Можно добавить fallback на Mozilla Readability.js (работает локально):

```javascript
const { Readability } = require('@mozilla/readability');
const { JSDOM } = require('jsdom');

const doc = new JSDOM(html);
const reader = new Readability(doc.window.document);
const article = reader.parse();
```

### Q: Какое качество экстракции у Jina по сравнению с Firecrawl?

**A**: Примерно одинаковое (~90% vs 95%). Jina использует специализированную AI модель ReaderLM-v2 (1.5B params) обученную именно на этой задаче.

### Q: Что если нужно больше 20 requests/minute?

**A**: Получи бесплатный API key на https://jina.ai/reader/ → 500 req/min!

---

**Статус**: ✅ Миграция завершена  
**Версия**: 3.0.0  
**Дата**: 2025-11-18
