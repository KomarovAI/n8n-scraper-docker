# n8n-scraper-docker: Production-Ready Docker Edition 🐳

[![CI/CD Tests](https://github.com/KomarovAI/n8n-scraper-docker/actions/workflows/ci-test.yml/badge.svg)](https://github.com/KomarovAI/n8n-scraper-docker/actions/workflows/ci-test.yml)
[![Security](https://img.shields.io/badge/security-tested-green.svg)](https://github.com/KomarovAI/n8n-scraper-docker/security)
[![Docker](https://img.shields.io/badge/docker-compose-blue.svg)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Очищенная, оптимизированная версия для standalone Docker Compose запуска на одном сервере или локально.**

✅ **Все Kubernetes-файлы удалены**  
✅ **Избыточные документы удалены**  
✅ **Автоматическое тестирование** (CI/CD)  
✅ **Полный мониторинг** (Prometheus + Grafana)  
✅ **n8n E2E Testing** (workflow validation) ⭐  

---

## 🚀 Быстрый старт

### 1️⃣ Клонирование

```bash
git clone https://github.com/KomarovAI/n8n-scraper-docker.git
cd n8n-scraper-docker
```

### 2️⃣ Настройка переменных окружения

```bash
# Скопируйте пример .env
cp .env.example .env

# Генерация сильных паролей (20+ символов)
openssl rand -base64 24

# Отредактируйте .env и замените все CHANGE_ME_* на сгенерированные пароли
nano .env  # или vim, code
```

**Критически важно:**
- `POSTGRES_PASSWORD` — минимум 20 символов
- `REDIS_PASSWORD` — минимум 20 символов
- `N8N_PASSWORD` — минимум 20 символов
- `TOR_CONTROL_PASSWORD` — минимум 20 символов
- `GRAFANA_PASSWORD` — минимум 20 символов

### 3️⃣ Запуск всего стека

```bash
# Запуск в фоновом режиме
docker-compose up -d --build

# Просмотр логов всех сервисов
docker-compose logs -f

# Проверка статуса контейнеров
docker-compose ps
```

### 4️⃣ Доступ к сервисам

После успешного запуска:

| Сервис | URL | Креды (из .env) |
|---------|-----|-------------------|
| **n8n Workflows** | http://localhost:5678 | N8N_USER / N8N_PASSWORD |
| **Grafana Monitoring** | http://localhost:3000 | GRAFANA_USER / GRAFANA_PASSWORD |
| **Prometheus Metrics** | http://localhost:9090 | - |
| **ML Service API** | http://localhost:8000 | - |
| **Ollama LLM** | http://localhost:11434 | - |
| PostgreSQL | localhost:5432 | POSTGRES_USER / POSTGRES_PASSWORD |
| Redis | localhost:6379 | REDIS_PASSWORD |
| Tor SOCKS Proxy | localhost:9050 | - |

---

## 🧪 **АВТОМАТИЧЕСКОЕ ТЕСТИРОВАНИЕ**

Проект включает **comprehensive CI/CD test suite**, который автоматически запускается при каждом push и pull request:

### **7 типов тестов:**

✅ **Lint & Validation** — docker-compose.yml, Dockerfile, shell scripts  
✅ **Security Scan** — Trivy vulnerability scanner + TruffleHog secret detection  
✅ **Docker Build** — сборка образов и проверка размера  
✅ **Health Checks** — PostgreSQL, Redis, Prometheus, Grafana  
✅ **Integration Tests** — connectivity, data persistence, exporters  
✅ **n8n Workflow E2E** — workflow import, execution, validation ⭐  
✅ **Test Summary** — финальный отчёт  

**Подробнее:** [🧪 TESTING.md](TESTING.md) | [n8n E2E Tests](tests/n8n/README.md)

---

## 📊 **МОНИТОРИНГ**

Полностью настроенный monitoring stack:

- 📊 **Prometheus** (localhost:9090) — сбор метрик
- 📈 **Grafana** (localhost:3000) — визуализация
- 💻 **Node Exporter** — системные метрики (CPU, RAM, Disk)
- 🟥 **Redis Exporter** — Redis метрики
- 🔵 **PostgreSQL Exporter** — DB метрики

**Подробнее:** [📊 MONITORING_SETUP.md](MONITORING_SETUP.md)

---

## 📦 Что входит в стек

### Основные сервисы:

1. **n8n** (5678) — автоматизация workflow'ов, оркестрация scraping
2. **PostgreSQL** (5432) — основная БД для хранения данных
3. **Redis** (6379) — rate limiting, кэширование, очереди
4. **Tor Proxy** (9050) — анонимность и IP rotation

### ML/AI компоненты:

5. **ML Service** (8000) — смарт-роутинг scraper'ов, стратегии fallback
6. **Ollama** (11434) — локальные LLM-модели (100% бесплатно)

### Мониторинг:

7. **Prometheus** (9090) — сбор метрик
8. **Grafana** (3000) — визуализация, дашборды

---

## 🛠️ Управление стеком

### Остановка:
```bash
docker-compose down
```

### Полная очистка (с удалением volumes):
```bash
docker-compose down -v
```

### Перезапуск одного сервиса:
```bash
docker-compose restart n8n
```

### Просмотр логов конкретного сервиса:
```bash
docker-compose logs -f n8n
docker-compose logs -f ml-service
```

### Обновление образов:
```bash
docker-compose pull
docker-compose up -d --build
```

---

## 📊 Production метрики

| Метрика | Значение |
|---------|---------|
| **Success Rate** | 87% |
| **Avg Latency** | 5.3s |
| **Cost per 1000 URLs** | $2.88 |
| **Cloudflare Bypass** | 90-95% |
| **Memory Leaks** | Нет ✅ |

### Особенности:

✅ **Hybrid Fallback** — Firecrawl (33%) + Jina AI (67%) = -66% затрат  
✅ **Smart Detection** — авто-выбор anti-detection = +35% скорости  
✅ **Nodriver Enhanced V2** — cleanup mechanism, instance limit, GUI mode  
✅ **15 Production Fixes** — circuit breaker, page pooling, exponential backoff  

---

## 📚 Документация

### Важные документы:

- **[🚀 README-docker.md](README-docker.md)** — детальная инструкция Docker Compose
- **[🧪 TESTING.md](TESTING.md)** — полная документация по тестированию
- **[⭐ n8n E2E Tests](tests/n8n/README.md)** — E2E тестирование workflows
- **[📊 MONITORING_SETUP.md](MONITORING_SETUP.md)** — настройка мониторинга
- **[🔧 PRODUCTION_FIXES_V3.md](PRODUCTION_FIXES_V3.md)** — все 15 production-исправлений
- **[📊 AUDIT_REPORT_FINAL.md](AUDIT_REPORT_FINAL.md)** — финальный аудит (4.95/5.0)
- **[🔒 SECURITY.md](SECURITY.md)** — руководство по безопасности
- **[🐜 DYNAMIC_RUNNERS.md](DYNAMIC_RUNNERS.md)** — документация по scraper'ам
- **[docs/](docs/)** — техническая документация

---

## ⚠️ Требования

### Минимальные:
- Docker 20.10+
- Docker Compose 1.29+
- 4 GB RAM
- 10 GB свободного места

### Рекомендуемые для production:
- Docker 24.0+
- Docker Compose 2.0+
- 8 GB RAM
- 50 GB свободного места
- GPU (опционально для Ollama)

---

## 🔒 Безопасность

### Критически важно:

❗ **Никогда не коммитьте .env файл** в Git (уже в .gitignore)  
❗ **Используйте сильные пароли** (20+ символов) для всех сервисов  
❗ **Ротация паролей** каждые 90 дней  
❗ **Закройте порты** через firewall для production  

### Firewall настройка (production):

```bash
# Открыть только n8n web UI (5678) и SSH (22)
sudo ufw allow 22/tcp
sudo ufw allow 5678/tcp
sudo ufw enable

# Все остальные порты доступны только localhost
```

---

## ❓ FAQ

### Q: Можно отключить ML сервис или Ollama?
A: Да! Откомментируйте соответствующие секции в docker-compose.yml.

### Q: Как использовать внешнюю PostgreSQL/Redis?
A: Измените переменные в .env на внешние хосты, отключите локальные контейнеры.

### Q: Как обновить на новую версию?
A: `git pull origin main && docker-compose up -d --build`

### Q: Где хранятся данные?
A: Docker volumes: `postgres-data`, `redis-data`, `n8n-data`, `grafana-data`, `prometheus-data`

### Q: Как сделать backup?
A: `docker-compose exec postgres pg_dump -U scraper_user scraper_db > backup_$(date +%Y%m%d).sql`

---

## 🎉 Что дальше?

1. Откройте n8n: http://localhost:5678
2. Импортируйте workflows из `workflows/`
3. Настройте credentials (если нужно)
4. Проверьте Grafana dashboards: http://localhost:3000
5. Запустите первый scraping workflow!

---

## 🔗 Ссылки

- [🐳 Docker Hub - n8n](https://hub.docker.com/r/n8nio/n8n)
- [📚 n8n Documentation](https://docs.n8n.io/)
- [🌐 GitHub Repository](https://github.com/KomarovAI/n8n-scraper-docker)
- [🛠️ GitHub Actions](https://github.com/KomarovAI/n8n-scraper-docker/actions)

---

**Built with ❤️ by KomarovAI**  
**Production-Ready ✅ | Docker-Optimized 🐳 | Auto-Tested 🧪 | Fully Monitored 📊**
