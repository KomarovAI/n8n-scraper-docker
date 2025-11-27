# 🧪 **AUTOMATED TESTING**

## 🎯 **ЧТО ТЕСТИРУЕТСЯ**

Проект включает comprehensive test suite, который автоматически запускается при каждом **push** и **pull request**.

### **6 типов тестов:**

```
1. ✅ Lint & Validation    — Проверка кода и конфигов
2. ✅ Security Scan       — Поиск уязвимостей и секретов
3. ✅ Docker Build        — Сборка образов
4. ✅ Health Checks       — Проверка здоровья сервисов
5. ✅ Integration Tests   — Полное интеграционное тестирование
6. ✅ Test Summary        — Общий результат
```

---

## 🛠️ **1. LINT & VALIDATION**

### **Что проверяется:**

#### **Docker Compose Validation:**
```bash
docker compose config > /dev/null
```
- ✅ Синтаксис docker-compose.yml
- ✅ Все переменные окружения
- ✅ Корректность volumes, networks

#### **Dockerfile Linting (Hadolint):**
```bash
hadolint Dockerfile.n8n-enhanced
```
- ✅ Best practices Docker
- ✅ Оптимизация слоёв
- ✅ Безопасность

#### **Shell Script Check (ShellCheck):**
```bash
shellcheck scripts/*.sh
```
- ✅ Синтаксис bash-скриптов
- ✅ Потенциальные ошибки

---

## 🔒 **2. SECURITY SCAN**

### **Что проверяется:**

#### **Trivy Vulnerability Scanner:**
```bash
trivy fs . --severity CRITICAL,HIGH
```
- ✅ Уязвимости в зависимостях
- ✅ CVE в npm/pip пакетах
- ✅ Проблемы в Docker образах

**Результаты отправляются в GitHub Security tab.**

#### **TruffleHog Secret Scanner:**
```bash
trufflehog filesystem .
```
- ✅ Поиск API keys
- ✅ Поиск паролей
- ✅ Поиск токенов

---

## 🐳 **3. DOCKER BUILD**

### **Что проверяется:**

#### **Image Build Test:**
```bash
docker buildx build -f Dockerfile.n8n-enhanced -t n8n-scraper:test .
```
- ✅ Успешная сборка
- ✅ Нет ошибок npm/pip install
- ✅ Все зависимости доступны

#### **Image Size Check:**
```bash
docker images n8n-scraper:test --format "{{.Size}}"
```
- ✅ Размер < 2GB (оптимизация)

---

## 🌡️ **4. HEALTH CHECKS**

### **Что проверяется:**

#### **PostgreSQL:**
```bash
docker compose exec postgres pg_isready -U scraper_user
```
- ✅ Сервис запущен
- ✅ Принимает подключения

#### **Redis:**
```bash
redis-cli -a $REDIS_PASSWORD ping
```
- ✅ Отвечает PONG
- ✅ Аутентификация работает

#### **Prometheus:**
```bash
curl -f http://localhost:9090/-/healthy
```
- ✅ API доступен
- ✅ Собирает метрики

#### **Grafana:**
```bash
curl -f http://localhost:3000/api/health
```
- ✅ UI доступен
- ✅ API работает

---

## 🔗 **5. INTEGRATION TESTS**

### **Что проверяется:**

#### **Service Connectivity:**
```bash
# PostgreSQL query
psql -U scraper_user -d scraper_db -c "SELECT 1;"

# Redis read/write
redis-cli SET test_key "test_value"
redis-cli GET test_key

# Prometheus targets
curl http://localhost:9090/api/v1/targets
```

#### **Exporters Response:**
```bash
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:9121/metrics  # Redis Exporter
curl http://localhost:9187/metrics  # PostgreSQL Exporter
```

#### **Data Persistence:**
```bash
# 1. Write data
CREATE TABLE test_table (id INT, data TEXT);
INSERT INTO test_table VALUES (1, 'test_data');

# 2. Restart service
docker compose restart postgres

# 3. Read data
SELECT * FROM test_table;  # Должно вернуть данные
```

---

## 🚀 **КАК ЗАПУСТИТЬ ТЕСТЫ ЛОКАЛЬНО**

### **Все тесты:**

```bash
# 1. Создать .env для тестов
cp .env.example .env
# Заменить пароли на тестовые

# 2. Lint & Validation
docker compose config
hadolint Dockerfile.n8n-enhanced
shellcheck scripts/*.sh

# 3. Security Scan
trivy fs . --severity CRITICAL,HIGH
trufflehog filesystem .

# 4. Docker Build
docker buildx build -f Dockerfile.n8n-enhanced -t n8n-scraper:test .

# 5. Health Checks
docker compose up -d postgres redis prometheus grafana
sleep 30
docker compose exec postgres pg_isready -U scraper_user
docker compose exec redis redis-cli -a $REDIS_PASSWORD ping
curl http://localhost:9090/-/healthy
curl http://localhost:3000/api/health

# 6. Integration Tests
# (см. секцию Integration Tests выше)

# 7. Cleanup
docker compose down -v
```

---

## 📊 **ЧТО ПРОИСХОДИТ ПРИ PUSH**

### **Автоматический запуск:**

```
git push origin main
    ↓
[🛠️] Lint & Validation (1-2 мин)
    │   • docker-compose.yml validation
    │   • Dockerfile linting
    │   • Shell script checks
    ↓
[🔒] Security Scan (2-3 мин)
    │   • Trivy vulnerability scan
    │   • TruffleHog secret detection
    ↓
[🐳] Docker Build (3-5 мин)
    │   • Build n8n-enhanced image
    │   • Check image size
    ↓
[🌡️] Health Checks (2-3 мин)
    │   • Start services
    │   • Check all health endpoints
    ↓
[🔗] Integration Tests (3-4 мин)
    │   • Test connectivity
    │   • Test data persistence
    │   • Test exporters
    ↓
[✅] Test Summary
    • All tests passed!
```

**Общее время: 12-18 минут**

---

## 🚨 **ЧТО ДЕЛАТЬ ПРИ ОШИБКЕ**

### **Проверьте GitHub Actions:**

1. Откройте: https://github.com/KomarovAI/n8n-scraper-docker/actions
2. Найдите последний запуск
3. Посмотрите логи падающего job

### **Типичные ошибки:**

#### **1. Lint Failed:**
```
Причина: Ошибка в docker-compose.yml
Решение: docker compose config  # Проверьте локально
```

#### **2. Security Scan Failed:**
```
Причина: Найдены уязвимости
Решение: Обновите зависимости (npm update, pip upgrade)
```

#### **3. Health Check Failed:**
```
Причина: Сервис не запустился
Решение: Проверьте логи docker compose logs <service>
```

#### **4. Integration Test Failed:**
```
Причина: Нет связи между сервисами
Решение: Проверьте depends_on в docker-compose.yml
```

---

## 📝 **STATUS BADGE**

Добавьте в README.md:

```markdown
[![CI/CD Tests](https://github.com/KomarovAI/n8n-scraper-docker/actions/workflows/ci-test.yml/badge.svg)](https://github.com/KomarovAI/n8n-scraper-docker/actions/workflows/ci-test.yml)
```

---

## ✅ **ЧЕК-ЛИСТ**

Перед каждым push:

- [ ] Проверил docker-compose.yml: `docker compose config`
- [ ] Проверил Dockerfile: `hadolint Dockerfile.n8n-enhanced`
- [ ] Проверил shell scripts: `shellcheck scripts/*.sh`
- [ ] Запустил локальные тесты
- [ ] Проверил, что нет секретов в коде

---

**Статус:** ✅ **COMPREHENSIVE TEST SUITE ГОТОВ!**  
**Покрытие:** Lint, Security, Build, Health, Integration  
**Автоматический запуск:** при каждом push/PR  
**Бесплатные runners:** GitHub Actions public repo
