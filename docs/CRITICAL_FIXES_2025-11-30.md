# Критические исправления 30.11.2025

## 🚨 Корневая проблема

**ГЛОБАЛЬНАЯ ПРИЧИНА:** Попытка использовать **Basic Auth** в n8n 1.x, где он **полностью удалён** с июля 2023 (n8n v1.0).

### Официальная документация n8n 1.0:

> "This change makes User Management mandatory and **removes support for other authentication methods, such as BasicAuth** and External JWT"
>
> — https://docs.n8n.io/1-0-migration-checklist/

### Цепочка ошибок:

```
1. Использование N8N_BASIC_AUTH_* (deprecated в n8n 1.0)
   ↓
2. Basic Auth не работает → добавление костылей
   ↓
3. Костыли не работают → больше костылей
   ↓
4. 30+ коммитов исправлений за 24 часа
   ↓
5. Система всё ещё нестабильна
```

---

## ✅ Применённые исправления

### 1️⃣ **Удаление Basic Auth** (Коммит: `e6a113d`)

**Файл:** `docker-compose.yml`

**Изменения:**
```yaml
# ❌ УДАЛЕНО:
N8N_BASIC_AUTH_ACTIVE: true
N8N_BASIC_AUTH_USER: ${N8N_USER}
N8N_BASIC_AUTH_PASSWORD: ${N8N_PASSWORD}

# ✅ ОСТАВЛЕНО (для scripts):
# N8N_USER и N8N_PASSWORD теперь используются только в
# scripts/import-n8n-workflows.sh для POST /rest/owner/setup
```

**Почему:**
- `N8N_BASIC_AUTH_*` переменные **полностью игнорируются** n8n >= 1.0
- Аутентификация теперь через **User Management** (cookie session)
- `N8N_USER`/`N8N_PASSWORD` - это **параметры для owner account**, НЕ Basic Auth!

---

### 2️⃣ **Исправление ML-зависимости** (Коммит: `e6a113d`)

**Файл:** `docker-compose.yml`

**Изменения:**
```yaml
n8n:
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
    # ml-service: ❌ УДАЛЕНО!
```

**Почему:**
- ML-сервис **НЕ критичен** для запуска n8n
- Если Ollama падает → n8n **продолжает работать**
- ML теперь опциональный компонент

---

### 3️⃣ **Увеличение healthcheck таймаутов** (Коммит: `e6a113d`)

**Файл:** `docker-compose.yml`

**Изменения:**
```yaml
n8n:
  healthcheck:
    start_period: 180s  # Было 90s
    retries: 10         # Было 3
    interval: 15s       # Было 30s

postgres:
  healthcheck:
    start_period: 60s   # Добавлено
```

**Почему:**
- n8n требует **30-60s для TypeORM миграций**
- Auth middleware инициализируется **после HTTP сервера**
- 90s было недостаточно → увеличено до 180s

---

### 4️⃣ **CI образ override** (Коммит: `774f70c`)

**Файл:** `docker-compose.ci.yml`

**Изменения:**
```yaml
# docker-compose.yml (не изменён)
n8n:
  image: ${N8N_IMAGE:-n8nio/n8n:latest}  # Production

# docker-compose.ci.yml (override)
n8n:
  image: n8n-enhanced:test  # CI
```

**Использование:**
```bash
# Production
docker compose up -d

# CI
docker compose -f docker-compose.yml -f docker-compose.ci.yml up -d
```

**Почему:**
- CI собирает кастомный образ с дополнительными скриптами
- Production использует стандартный образ n8n
- Чистое разделение CI/Production конфигов

---

### 5️⃣ **ML Graceful Degradation** (Коммит: `f1af24b`)

**Файл:** `ml/optimized_ai_router.py`

**Изменения:**
```python
# ❌ СТАРЫЙ КОД (крашился):
self.classifier = self._load_classifier()  # Exception → crash

# ✅ НОВЫЙ КОД (graceful):
try:
    self.classifier = self._load_classifier()
    logger.info("✅ ML classifier loaded successfully")
except Exception as e:
    logger.warning(f"⚠️ ML classifier not loaded: {e}")
    logger.warning("⚠️ ML predictions disabled, using rule-based only")
    self.classifier = None  # Продолжаем работу
```

**Почему:**
- `models/scraping_classifier.pkl` может отсутствовать
- ML-сервис теперь **НЕ крашится**
- Автоматически использует rule-based метод

---

### 6️⃣ **Обновление .env.example** (Коммит: `e7bfcf9`)

**Файл:** `.env.example`

**Изменения:**
```bash
# ==========================================
# n8n User Management Configuration (n8n 1.x+)
# ==========================================
# ВАЖНО: ЭТО НЕ Basic Auth!
#
# n8n 1.0+ удалил Basic Auth полностью!
# Источник: https://docs.n8n.io/1-0-migration-checklist/
#
# N8N_USER - ЭТО email для owner account (НЕ Basic Auth username!)
# N8N_PASSWORD - ЭТО пароль owner account (НЕ Basic Auth password!)
# ==========================================
N8N_USER=admin@example.com
N8N_PASSWORD=CHANGE_ME_TO_STRONG_PASSWORD_MIN_20_CHARS
```

**Почему:**
- Предотвращает путаницу с Basic Auth
- Явно указывает назначение переменных
- Ссылка на официальную документацию

---

## 🔧 Инструкции по миграции

### Для существующих установок

#### Шаг 1: Обновить код

```bash
cd n8n-scraper-docker
git pull origin main
```

#### Шаг 2: Обновить .env файл

```bash
# Проверьте ваш .env:
cat .env | grep N8N_

# Удалите устаревшие переменные:
# ❌ N8N_BASIC_AUTH_ACTIVE
# ❌ N8N_BASIC_AUTH_USER 
# ❌ N8N_BASIC_AUTH_PASSWORD

# Оставьте только:
# ✅ N8N_USER=admin@example.com
# ✅ N8N_PASSWORD=<ваш_пароль>
```

#### Шаг 3: Перезапустить сервисы

```bash
# Остановить старые контейнеры
docker compose down

# Запустить с новыми настройками
docker compose up -d

# Проверить логи
docker compose logs -f n8n
```

#### Шаг 4: Создать owner account

**ОТКРОЙТЕ в браузере:** http://localhost:5678

n8n автоматически перенаправит на `/setup` для создания owner.

Используйте **те же email/password** из `N8N_USER`/`N8N_PASSWORD` в `.env`.

---

### Для новых установок

Следуйте обновлённому README.md:

```bash
git clone https://github.com/KomarovAI/n8n-scraper-docker.git
cd n8n-scraper-docker
chmod +x scripts/setup.sh && ./scripts/setup.sh
docker compose up -d
```

Откройте http://localhost:5678 и создайте owner account.

---

## 🐞 Troubleshooting

### Проблема: "401 Unauthorized" при импорте workflows

**Причина:** Owner account ещё не создан.

**Решение:**
```bash
# Откройте в браузере
open http://localhost:5678

# Создайте owner account через UI
# Используйте email/password из .env

# Повторите импорт
bash scripts/import-n8n-workflows.sh
```

---

### Проблема: n8n healthcheck проваливается

**Причина:** Недостаточное время для инициализации.

**Решение:**
```bash
# Проверьте логи
docker compose logs n8n | tail -100

# Если видите "Running database migrations":
# Подождите 2-3 минуты

# Проверьте статус
docker compose ps n8n
# Должен быть: "healthy"
```

---

### Проблема: ML-сервис не запускается

**Решение:** Это нормально! ML-сервис **опциональный**.

```bash
# Проверьте что n8n работает
curl http://localhost:5678/healthz
# Должен вернуть: {"status":"ok"}

# n8n продолжает работать без ML!
```

---

## 📚 Официальная документация

### n8n 1.x User Management:

1. **Миграционный гайд:** https://docs.n8n.io/1-0-migration-checklist/
2. **User Management:** https://docs.n8n.io/hosting/configuration/user-management-self-hosted/
3. **REST API:** https://docs.n8n.io/api/authentication/

### n8n REST API эндпоинты:

```bash
# Создание owner
POST /rest/owner/setup
Body: { "email": "admin@example.com", "firstName": "Admin", "lastName": "User", "password": "..." }

# Вход (если owner уже создан)
POST /rest/login
Body: { "email": "admin@example.com", "password": "..." }
Response: Cookie: n8n-auth=...

# Все другие запросы
GET /rest/workflows
Headers: Cookie: n8n-auth=<value>
```

---

## ✅ Проверка что всё работает

```bash
# 1. Сервисы запущены
docker compose ps
# Ожидаем: n8n, postgres, redis - "healthy"

# 2. n8n отвечает
curl http://localhost:5678/healthz
# Ожидаем: {"status":"ok"}

# 3. Owner создан
open http://localhost:5678
# Если перенаправляет на /setup → создайте owner
# Если показывает /login → owner уже создан ✅

# 4. Workflows импортированы
bash scripts/import-n8n-workflows.sh
# Ожидаем: "🎉 All workflows imported successfully!"
```

---

## 📊 Резюме

### Что было исправлено:

- ❌ **Удалено:** Basic Auth (не работает в n8n 1.x)
- ✅ **Исправлено:** ML-зависимость (опциональная)
- ✅ **Увеличено:** Healthcheck таймауты
- ✅ **Добавлено:** CI образ override
- ✅ **Добавлено:** ML graceful degradation
- ✅ **Обновлено:** .env.example с правильными комментариями

### Результат:

- 🚀 **Стабильный запуск** без race conditions
- 🚀 **n8n 1.x совместимость** (правильный User Management)
- 🚀 **Graceful degradation** (ML не ломает систему)
- 🚀 **Чистый CI/Production** разделение

---

**Дата:** 30 ноября 2025  
**Автор:** KomarovAI  
**Коммиты:** `e6a113d`, `e7bfcf9`, `774f70c`, `f1af24b`  
**Статус:** ✅ Production-ready