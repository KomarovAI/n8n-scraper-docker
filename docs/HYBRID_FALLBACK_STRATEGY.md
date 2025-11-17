# 🎯 Hybrid Fallback Strategy: Firecrawl + Jina AI Reader

## 💡 Идея

Используем **лучшее из двух миров**:

- **Firecrawl** (платный, $0.003/req) - высокое качество (95%), медленный (10-30s)
- **Jina AI Reader** (бесплатный) - хорошее качество (90%), быстрый (3-5s)

### 🎯 Стратегия:

```
Каждый 3-й URL через Firecrawl (пока есть токены)
Остальные через Jina AI Reader
```

**Пример** (на 9 URLs):
```
URL #1 → Jina AI Reader  (бесплатно, 4s)
URL #2 → Jina AI Reader  (бесплатно, 4s)
URL #3 → Firecrawl       ($0.003, 15s) 🔥
URL #4 → Jina AI Reader  (бесплатно, 4s)
URL #5 → Jina AI Reader  (бесплатно, 4s)
URL #6 → Firecrawl       ($0.003, 15s) 🔥
URL #7 → Jina AI Reader  (бесплатно, 4s)
URL #8 → Jina AI Reader  (бесплатно, 4s)
URL #9 → Firecrawl       ($0.003, 15s) 🔥

Total cost: $0.009 (vs $0.027 если все через Firecrawl)
Экономия: 66%! 💰
```

---

## 📊 Преимущества

| Метрика | Только Firecrawl | Только Jina | **Hybrid (33% Firecrawl)** |
|---------|------------------|--------------|---------------------------|
| 💰 Стоимость | $3/1000 | $0 | **$1/1000** (↓ 66%) |
| ⏱️ Средняя latency | 20s | 4s | **∼8s** (↓ 40%) |
| 🎯 Качество | 95% | 90% | **∼92%** |
| 🔐 API keys | 1 нужен | 0 нужно | **1 нужен** |

---

## 🚀 Как использовать

### 1️⃣ Настройка Environment Variables

```bash
# ОБЯЗАТЕЛЬНО: Firecrawl API key
export FIRECRAWL_API_KEY=fc-xxxxxxxxxxxxxx

# ОПЦИОНАЛЬНО: Jina API key (для 500 req/min вместо 20)
export JINA_API_KEY=jina_xxxxxxxxxx  # Бесплатный на https://jina.ai/reader/
```

### 2️⃣ Интеграция в N8N Workflow

**Шаг 1**: Открой workflow в N8N UI

**Шаг 2**: Найди node "Firecrawl Fallback (with Retry)" или "Jina AI Reader Fallback"

**Шаг 3**: Замени код на:
```javascript
// Скопируй весь код из:
// workflows/code-nodes/hybrid-fallback-firecrawl-jina.js
```

**Шаг 4**: Переименуй node в **"Hybrid Fallback (Firecrawl + Jina)"**

**Шаг 5**: Сохрани и тестируй!

---

## 📝 Пример работы

### Входные данные:
```json
{
  "urls": [
    "https://complex-site-1.com",
    "https://complex-site-2.com",
    "https://complex-site-3.com",
    "https://complex-site-4.com",
    "https://complex-site-5.com",
    "https://complex-site-6.com"
  ]
}
```

### Логи выполнения:
```
🔥 Hybrid Fallback: processing 6 failed items
✅ Firecrawl API: Available
✅ Jina API key: Available (500 req/min)

⚡ [1/6] Using Jina AI Reader for https://complex-site-1.com
⚡ [2/6] Using Jina AI Reader for https://complex-site-2.com
🔥 [3/6] Using Firecrawl for https://complex-site-3.com
⚡ [4/6] Using Jina AI Reader for https://complex-site-4.com
⚡ [5/6] Using Jina AI Reader for https://complex-site-5.com
🔥 [6/6] Using Firecrawl for https://complex-site-6.com

📊 HYBRID FALLBACK STATISTICS:
   Total processed: 6
   ✅ Successful: 6
   ❌ Failed: 0

🎯 RUNNER DISTRIBUTION:
   🔥 Firecrawl: 2 requests (33.3%)
   ⚡ Jina AI: 4 requests (66.7%)

💰 COST ANALYSIS:
   Firecrawl cost: $0.0060
   Jina cost: $0.00 (FREE)
   Total cost: $0.0060
   vs Full Firecrawl: $0.0180 (saved 66.7%)
```

---

## ⚙️ Настройка стратегии

### Изменить частоту Firecrawl

**Каждый 2-ой** (50% Firecrawl, 50% Jina):
```javascript
if (hasFirecrawl && (i % 2 === 1)) {
  result = await retryFirecrawl(url, MAX_RETRIES);
}
```

**Каждый 4-ый** (25% Firecrawl, 75% Jina):
```javascript
if (hasFirecrawl && (i % 4 === 3)) {
  result = await retryFirecrawl(url, MAX_RETRIES);
}
```

**Каждый 5-ый** (20% Firecrawl, 80% Jina):
```javascript
if (hasFirecrawl && (i % 5 === 4)) {
  result = await retryFirecrawl(url, MAX_RETRIES);
}
```

---

## 🔄 Fallback логика

### Умный fallback при ошибках:

1. **Firecrawl провалился** → автоматически переключаемся на Jina
2. **Firecrawl quota exceeded** → все остальные через Jina
3. **Jina провалился** → retry с exponential backoff

```javascript
// Пример из кода:
if (error.message.includes('quota') || error.message.includes('limit')) {
  console.warn(`⚠️ Firecrawl quota exceeded, falling back to Jina`);
  return await retryJinaReader(url, MAX_RETRIES);
}
```

---

## 📊 Monitoring

### Prometheus Metrics

```promql
# Распределение по runners
sum(n8n_scrape_requests_total{runner="firecrawl"}) by (runner)
sum(n8n_scrape_requests_total{runner="jina_ai_reader"}) by (runner)

# Средняя latency
avg(n8n_scrape_latency_seconds{runner="firecrawl"})
avg(n8n_scrape_latency_seconds{runner="jina_ai_reader"})

# Cost tracking
sum(n8n_scrape_requests_total{runner="firecrawl"}) * 0.003
```

### Журналы

```bash
kubectl logs -f n8n-scraper-0 -n n8n-scraper | grep "HYBRID FALLBACK"
```

---

## 💸 Расчёт экономии

### На 10,000 URLs/месяц (5% fallback rate = 500 URLs)

| Сценарий | Firecrawl | Jina | Total Cost | Экономия |
|----------|-----------|------|------------|----------|
| **100% Firecrawl** | 500 ($1.50) | 0 | **$1.50** | - |
| **100% Jina** | 0 | 500 | **$0.00** | $1.50 |
| **Hybrid 33% Firecrawl** | 167 ($0.50) | 333 | **$0.50** | **$1.00** |

**Годовая экономия**: $1.00 × 12 = **$12/год** 💰

---

## ❓ FAQ

### Q: Почему именно 33% (each 3rd)?

**A**: Баланс между:
- Экономией (меньше Firecrawl = меньше $)
- Качеством (больше Firecrawl = лучше результаты)

Можно настроить под свои нужды!

### Q: Что если закончатся токены Firecrawl?

**A**: Автоматически переключаемся на 100% Jina! Код обрабатывает `quota exceeded` ошибки.

### Q: Можно ли использовать только Jina?

**A**: Да! Просто не устанавливай `FIRECRAWL_API_KEY` → все будет через Jina.

### Q: Как проверить что работает?

**A**: Смотри логи и Prometheus metrics `runner="firecrawl"` vs `runner="jina_ai_reader"`.

---

## 🔗 Ссылки

- 💻 [Hybrid Fallback Code](../workflows/code-nodes/hybrid-fallback-firecrawl-jina.js)
- 🔧 [Jina AI Reader Helper](../utils/jina-reader-helper.js)
- 📖 [Firecrawl to Jina Migration](./FIRECRAWL_TO_JINA_MIGRATION.md)
- 🚀 [Production Fixes Guide](../PRODUCTION_FIXES_V3.md)

---

**Статус**: ✅ Production Ready  
**Версия**: 3.0.0  
**Дата**: 2025-11-18
