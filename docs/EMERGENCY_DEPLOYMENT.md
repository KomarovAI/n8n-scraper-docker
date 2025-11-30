# 🚨 Emergency Deployment Guide

## ⚠️ **CRITICAL WARNING**

**Emergency Deployment workflow** (`06-emergency-deployment.yaml`) деплоит код **БЕЗ ПРОВЕРОК**:
- ✗ Нет infrastructure checks
- ✗ Нет n8n validation
- ✗ Нет E2E tests
- ✗ Нет code quality checks
- ✗ Нет security scans

**Используй ONLY для экстренных ситуаций!**

---

## 🎯 Когда использовать

### ✅ **ПРАВИЛЬНЫЕ сценарии:**

1. **Critical Hotfix**
   - Production сломан и нужен немедленный fix
   - Есть проверенный fix для критической уязвимости
   - Производственная проблема затрагивает пользователей

2. **Rollback**
   - Откат на предыдущую стабильную версию
   - Обычный CI/CD сломан и нужен emergency rollback

3. **Emergency Configuration**
   - Критическое изменение конфигурации
   - API keys rotation в экстренной ситуации

4. **CI/CD Pipeline Down**
   - GitHub Actions сломан
   - Другие workflows недоступны

### ❌ **НЕПРАВИЛЬНЫЕ сценарии:**

1. **Лень ждать tests**
   - НЕ используй для обхода проверок
   - Automated tests нужны для безопасности

2. **Regular deployments**
   - Используй обычный workflow `04-production-deployment.yaml`

3. **Feature deployments**
   - Новые фичи MUST пройти full validation

4. **Непонятно, почему validation падает**
   - Сначала исправь проблему, а не обходи checks

---

## 🚀 Как использовать

### Шаг 1: Открыть GitHub Actions

1. Перейди на GitHub: [n8n-scraper-docker](https://github.com/KomarovAI/n8n-scraper-docker)
2. Нажми **Actions** (верхняя панель)
3. В левом меню найди: **"🚨 Emergency Deployment (Manual Only)"**

### Шаг 2: Запустить workflow

1. Нажми **"Run workflow"** (правая сторона, зелёная кнопка)
2. Выбери **branch**: `main` (или hotfix ветку)
3. **Заполни параметры:**

#### Параметры:

| Параметр | Описание | Пример | Обязательно |
|----------|-----------|---------|-------------|
| **deployment_reason** | Причина деплоя | "Hotfix: critical bug in webhook handler" | ✅ Да |
| **skip_backup** | Пропустить backup | `false` (рекомендовано) | ❌ Нет |
| **force_restart** | Перезапустить всё | `false` (обычно) | ❌ Нет |

**Пример заполнения:**

```
deployment_reason: "Emergency: fixing n8n webhook timeout (commit abc1234)"
skip_backup: false
force_restart: false
```

4. Нажми **"Run workflow"** (зелёная кнопка внизу)

### Шаг 3: Мониторинг деплоя

1. Workflow запустится немедленно
2. Следи за логами в real-time
3. Увидишь warning banner:

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║               ⚠️  EMERGENCY DEPLOYMENT MODE ⚠️                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Шаг 4: Проверка после деплоя

1. **Проверь n8n:**
   ```bash
   curl http://192.168.0.105:5678/healthz
   ```

2. **Проверь сервисы:**
   ```bash
   ssh artikk@192.168.0.105
   cd /home/artikk/n8n-production
   docker compose ps
   ```

3. **Посмотри логи:**
   ```bash
   docker compose logs -f n8n
   ```

4. **Проверь функциональность:**
   - Открой http://192.168.0.105:5678
   - Проверь workflows
   - Запусти тестовый workflow

---

## 📊 Что происходит под капотом

### Workflow Steps:

```
1. ⚠️  Emergency Warning
   └─ Отображает warning banner
   └─ Логирует причину и параметры

2. 💾 Emergency Backup (если не skip_backup)
   └─ PostgreSQL dump → /home/artikk/n8n-backups/
   └─ .env → /home/artikk/n8n-backups/
   └─ docker-compose.yml → /home/artikk/n8n-backups/

3. 🚀 Emergency Deploy
   └─ Checkout code from branch
   └─ Sync to /home/artikk/n8n-production/
   └─ Create .env from GitHub Secrets
   └─ Build Docker images
   └─ Stop services (graceful or force)
   └─ Start services
   └─ Wait for n8n health (60s timeout)
   └─ Basic health checks
   └─ Display deployment info

4. 📊 Summary
   └─ Генерирует итоговый отчёт
   └─ Next steps и troubleshooting
```

### Время выполнения:

- **Быстрый деплой**: ~3-5 минут
- **С backup**: ~5-7 минут
- **Force restart**: ~7-10 минут

---

## 🔄 Rollback процедура

### Если деплой сломался:

1. **Automatic Rollback** (встроенный):
   - Workflow автоматически пытается restart сервисы
   - Использует предыдущий Docker image

2. **Manual Rollback** (ручной):

```bash
# Подключиться к серверу
ssh artikk@192.168.0.105
cd /home/artikk/n8n-production

# 1. Остановить сломанные сервисы
docker compose down n8n tor

# 2. Восстановить из backup
cd /home/artikk/n8n-backups
ls -lt emergency-backup-* | head -5  # Найти последний backup

# 3. Восстановить .env
cp emergency-backup-20251130_201200.env /home/artikk/n8n-production/.env

# 4. Восстановить docker-compose.yml (если нужно)
cp emergency-backup-20251130_201200.docker-compose.yml /home/artikk/n8n-production/docker-compose.yml

# 5. Восстановить базу (если нужно)
gunzip -c emergency-backup-20251130_201200.sql.gz | docker exec -i postgres psql -U n8n n8n

# 6. Запустить сервисы
cd /home/artikk/n8n-production
docker compose up -d n8n tor

# 7. Проверить
docker compose logs -f n8n
```

### Если нужен полный rollback:

```bash
# Rollback на предыдущий commit через emergency deployment
# 1. На GitHub: Actions → Emergency Deployment → Run workflow
# 2. Branch: main (or previous stable branch/tag)
# 3. deployment_reason: "Rollback to previous stable version (commit <SHA>)"
```

---

## 🛡️ Best Practices

### ДО деплоя:

1. **✅ Проверь commit**
   - Убедись, что деплоишь правильный commit
   - Проверь изменения в git diff

2. **✅ Запиши причину**
   - Чёткое описание проблемы
   - Укажи commit SHA

3. **✅ Оставь backup enabled**
   - Пропускай backup только если критически важна скорость

4. **✅ Уведоми команду**
   - Slack/Telegram: "🚨 Emergency deployment in progress"
   - Укажи причину

### ВО ВРЕМЯ деплоя:

1. **👀 Мониторь логи**
   - Следи за GitHub Actions logs
   - Проверяй каждый step

2. **🕒 Будь готов к rollback**
   - Держи открытым SSH к серверу
   - Знай backup location

### ПОСЛЕ деплоя:

1. **✅ Проверь сервисы**
   - n8n UI: http://192.168.0.105:5678
   - Grafana: http://192.168.0.105:3001
   - Запусти smoke tests

2. **✅ Мониторинг 10-15 минут**
   - Смотри логи: `docker compose logs -f n8n`
   - Проверяй metrics в Grafana

3. **✅ Запусти full validation**
   - Когда ситуация стабилизировалась:
   ```
   GitHub → Actions → "2 n8n Validation" → Run workflow
   GitHub → Actions → "3 Full E2E Testing" → Run workflow
   ```

4. **📝 Документируй**
   - Что было сломано
   - Какой fix применён
   - Результат
   - Next steps

---

## 📊 Logging & Monitoring

### Где смотреть логи:

1. **GitHub Actions:**
   - Actions → Emergency Deployment → Последний run

2. **На сервере:**
   ```bash
   # n8n logs
   docker compose logs -f n8n
   
   # Все сервисы
   docker compose logs -f
   
   # Последние 500 строк
   docker compose logs --tail=500 n8n
   ```

3. **Backups:**
   ```bash
   ls -lht /home/artikk/n8n-backups/
   ```

### Key Metrics:

- **n8n response time**: < 500ms (норма)
- **Memory usage**: < 2GB (n8n + PostgreSQL)
- **CPU usage**: < 50% (idle)
- **Active workflows**: количество активных

---

## ❓ FAQ

### Q: Можно ли использовать для обычных деплоев?
**A:** Нет. Используй `04-production-deployment.yaml` для regular deployments.

### Q: Что если backup не нужен?
**A:** Установи `skip_backup: true`, но **НЕ рекомендуется**. Backup сэкономит 1-2 минуты, но спасёт при проблемах.

### Q: Когда использовать `force_restart`?
**A:** Только если:
- База данных сломана
- Нужно очистить Docker volumes
- Полностью перезапустить всё

⚠️ **Внимание**: `force_restart` удаляет volumes с `-v` флагом!

### Q: Сколько хранятся backups?
**A:** Backups не удаляются автоматически. Удаляй старые вручную:
```bash
cd /home/artikk/n8n-backups
ls -lt emergency-backup-*
rm emergency-backup-20251101_*  # Удалить старые
```

### Q: Можно запустить из фичерной ветки?
**A:** Да. Выбери нужную branch при запуске workflow.

### Q: Что если workflow failed?
**A:** Смотри раздел "Rollback процедура" выше. Автоматический rollback запустится, но может потребоваться manual intervention.

---

## 🔗 Ссылки

- **Workflow File**: [.github/workflows/06-emergency-deployment.yaml](../.github/workflows/06-emergency-deployment.yaml)
- **Regular Deployment**: [04-production-deployment.yaml](../.github/workflows/04-production-deployment.yaml)
- **Disaster Recovery**: [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

---

## ⚠️ ФИНАЛЬНОЕ ПРЕДУПРЕЖДЕНИЕ

**Emergency Deployment - это крайняя мера.**

✅ **Используй только** для:
- Critical hotfixes
- Emergency rollbacks
- Production incidents

❌ **НЕ используй** для:
- Regular deployments
- Feature releases
- "Лень ждать tests"

**Правильное использование = спасённый production.**

**Неправильное использование = сломанный production.**

---

**Версия**: 1.0 | **Updated**: 2025-11-30
