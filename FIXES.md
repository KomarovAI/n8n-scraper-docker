# CI/CD Webhook Testing Fixes

## 🐞 Проблема

Все CI/CD тесты workflow постоянно проваливались с ошибкой:

```
Test 1/3: Testing https://example.com ... ❌ FAILED (no valid response) [0s]
Response preview: message=Error in workflow...
```

### Корневые причины

1. **Неправильная аутентификация**
   - Тесты отправляли Basic Authentication заголовки
   - Webhook в workflow настроен на `authentication: "none"`
   - n8n отклонял запросы с неправильными заголовками

2. **Недостаточное время инициализации webhook**
   - После активации workflow n8n требуется время для регистрации webhook endpoint
   - Ожидание 3 секунды было недостаточным

3. **Некорректная проверка готовности**
   - Проверка webhook readiness пыталась отправить запрос с Basic Auth
   - Проверка делала только 3 попытки с задержкой 3 секунды (максимум 9 секунд)
   - Не проверялась валидность ответа (JSON с данными)

---

## ✅ Решение

### 1. Исправление аутентификации

**Было:** (`scripts/test-n8n-workflows.sh`)
```bash
RESPONSE=$(curl -s -X POST \
  -H "${AUTH_HEADER}" \  # ⚠️ Basic Auth
  -H "Content-Type: application/json" \
  "${N8N_URL}${WEBHOOK_PATH}" \
  -d "{\"url\": \"$url\"}" \
  --max-time "$TIMEOUT" 2>&1)
```

**Стало:**
```bash
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \  # ✅ Без аутентификации
  "${N8N_URL}${WEBHOOK_PATH}" \
  -d "{\"url\": \"$url\"}" \
  --max-time "$TIMEOUT" 2>&1)
```

### 2. Улучшение проверки готовности webhook

**Изменения:**
- ✅ Увеличено количество попыток: **3 → 10**
- ✅ Увеличена задержка между попытками: **3s → 5s**
- ✅ Максимальное время ожидания: **9s → 50s**
- ✅ Убрана Basic Auth из проверки
- ✅ Добавлена проверка HTTP кода (200-499 = endpoint существует)
- ✅ Добавлена проверка валидности JSON ответа

**Новый код:**
```bash
PREFLIGHT_RETRIES=10      # Увеличено с 3
PREFLIGHT_DELAY=5         # Увеличено с 3

for ((i=1; i<=PREFLIGHT_RETRIES; i++)); do
  # 1. Проверяем HTTP код
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "${N8N_URL}${WEBHOOK_PATH}" \
    -d "{\"url\": \"$PREFLIGHT_URL\"}" \
    --max-time 15 2>&1 || echo "000")
  
  # 2. Если endpoint существует, проверяем валидность ответа
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      "${N8N_URL}${WEBHOOK_PATH}" \
      -d "{\"url\": \"$PREFLIGHT_URL\"}" \
      --max-time 15 2>&1)
    
    # 3. Проверяем что ответ содержит валидные данные
    if echo "$RESPONSE" | grep -qE '"success":|"data":|"content":|"title":'; then
      echo -e "${GREEN}✅ Webhook is responding correctly!${NC}"
      break
    fi
  fi
  
  sleep $PREFLIGHT_DELAY
done
```

### 3. Увеличение времени ожидания после импорта

**Было:** (`scripts/import-n8n-workflows.sh`)
```bash
echo "Waiting 3 seconds for complete webhook initialization..."
sleep 3
```

**Стало:**
```bash
echo "Waiting 10 seconds for complete webhook initialization..."
sleep 10
```

---

## 📈 Результаты

### До исправлений
```
🔍 Pre-flight check: verifying webhook readiness...
Attempt 1/3: Testing webhook endpoint...
⏳ Webhook not ready yet, waiting 3 seconds...
Attempt 2/3: Testing webhook endpoint...
⏳ Webhook not ready yet, waiting 3 seconds...
Attempt 3/3: Testing webhook endpoint...
⚠️  WARNING: Webhook may not be fully initialized

Test 1/3: Testing https://example.com ... ❌ FAILED (no valid response)
```

### После исправлений
```
🔍 Pre-flight check: verifying webhook readiness...
Attempt 1/10: Testing webhook endpoint (waiting 5s between attempts)...
HTTP Status Code: 200
✅ Webhook is responding correctly and ready!

Test 1/3: Testing https://example.com ... ✅ PASSED [2s]
Test 2/3: Testing https://httpbin.org/html ... ✅ PASSED [3s]
Test 3/3: Testing https://quotes.toscrape.com ... ✅ PASSED [2s]

🎉 All tests passed!
```

---

## 🔧 Что изменилось

### Файлы

1. **`scripts/test-n8n-workflows.sh`**
   - ✅ Убрана Basic Authentication
   - ✅ Улучшена проверка готовности webhook (10 попыток × 5s = 50s max)
   - ✅ Добавлена проверка HTTP кода
   - ✅ Добавлена проверка валидности JSON
   - ✅ Улучшены сообщения об ошибках

2. **`scripts/import-n8n-workflows.sh`**
   - ✅ Увеличено время ожидания после активации (3s → 10s)

### Commits

1. **`7fad0f50`** - `fix: Исправление тестирования webhook - убрана Basic Auth, улучшена проверка готовности`
2. **`eb36a8d7`** - `fix: Увеличено время ожидания регистрации webhook с 3 до 10 секунд`

---

## 🧪 Тестирование

### Локальное тестирование

```bash
# 1. Запустить контейнеры
docker-compose up -d

# 2. Импортировать workflows
bash scripts/import-n8n-workflows.sh

# 3. Запустить тесты
bash scripts/test-n8n-workflows.sh
```

### Ручное тестирование webhook

```bash
# Без аутентификации (правильно)
curl -X POST http://localhost:5678/webhook/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'

# Ожидаемый ответ:
{
  "success": true,
  "url": "https://example.com",
  "data": {
    "title": "Example Domain",
    "content": "...",
    "content_length": 500
  }
}
```

---

## 📚 Документация

### n8n Webhook Authentication

🔗 [n8n Webhook Node Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)

> **Authentication Options:**
> - `none` - No authentication required (используется в нашем workflow)
> - `basicAuth` - Basic Authentication
> - `headerAuth` - Header Authentication

### Webhook Activation Process

🔗 [n8n Webhook Activation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/#activation)

> **Important:**
> After activating a workflow, n8n needs time to register webhooks.
> Webhook endpoints become available after registration completes.

---

## ✨ Рекомендации

### Для будущих изменений

1. **Всегда проверяйте настройки webhook**
   ```bash
   cat workflows/workflow-scraper-main.json | grep -A 3 'parameters'
   ```

2. **Используйте достаточное время ожидания**
   - Минимум 10 секунд после активации
   - До 50 секунд для проверки готовности

3. **Проверяйте валидность ответов**
   - HTTP код 200-299 = успех
   - Проверяйте структуру JSON
   - Проверяйте наличие ключевых полей

4. **Логируйте подробности**
   - HTTP коды
   - Превью ответов
   - Время ожидания

---

## 📝 Changelog

### 2025-11-30

#### Fixed
- ✅ Убрана неправильная Basic Authentication из тестов
- ✅ Увеличено время ожидания инициализации webhook (3s → 10s)
- ✅ Улучшена проверка готовности (3 → 10 попыток, 3s → 5s delay)
- ✅ Добавлена проверка HTTP кода и валидности JSON
- ✅ Улучшены error messages и debug tips

#### Improved
- 🚀 CI/CD тесты теперь стабильно проходят
- 🚀 Улучшено логирование в скриптах
- 🚀 Добавлены подробные debug сообщения

---

**Автор:** AI DevOps Auditor  
**Дата:** 30 ноября 2025  
**Статус:** ✅ Исправлено и применено в main