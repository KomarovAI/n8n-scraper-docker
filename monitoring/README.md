# 📊 Monitoring Stack

## 🎯 Что включено

### **✅ Готово к работе:**

1. **Prometheus** (localhost:9090) — сбор метрик
2. **Grafana** (localhost:3000) — визуализация
3. **Node Exporter** (localhost:9100) — системные метрики (CPU, RAM, Disk)
4. **Redis Exporter** (localhost:9121) — метрики Redis
5. **PostgreSQL Exporter** (localhost:9187) — метрики базы данных

---

## 🚀 Быстрый старт

### **1. Запуск всего стека:**

```bash
docker-compose up -d
```

### **2. Проверка статуса:**

```bash
docker-compose ps

# Должны быть running/healthy:
# - n8n-prometheus
# - n8n-grafana
# - n8n-node-exporter
# - n8n-redis-exporter
# - n8n-postgres-exporter
```

### **3. Открыть Grafana:**

```
URL: http://localhost:3000
Логин: admin (из .env: GRAFANA_USER)
Пароль: ваш_пароль (из .env: GRAFANA_PASSWORD)
```

### **4. Проверить Prometheus targets:**

```
URL: http://localhost:9090/targets

Все targets должны быть UP (зелёные):
✅ prometheus (1/1 up)
✅ node (1/1 up)
✅ redis (1/1 up)
✅ postgres (1/1 up)
✅ ml-service (1/1 up)
✅ n8n (1/1 up)
✅ grafana (1/1 up)
```

---

## 📋 Что можно увидеть

### **Системные метрики (Node Exporter):**

- CPU использование (%)
- RAM использование (GB)
- Disk занятость (%)
- Network traffic (in/out)
- Load average (1m, 5m, 15m)

### **Redis метрики (Redis Exporter):**

- Количество ключей
- Использование памяти
- Операции в секунду
- Cache hit/miss rate
- Connected clients

### **PostgreSQL метрики (PostgreSQL Exporter):**

- Количество соединений
- Запросы в секунду
- Размер базы данных
- Transaction rate
- Slow queries

---

## 📈 Как добавить готовые дашборды

### **Вариант 1: Через Grafana UI (проще)**

1. Откройте Grafana: http://localhost:3000
2. Нажмите `+` → `Import`
3. Введите ID дашборда с grafana.com:

**Рекомендуемые дашборды:**

| Dashboard | ID | Описание |
|-----------|-----|----------|
| **Node Exporter Full** | `1860` | Полный мониторинг системы |
| **Redis Dashboard** | `763` | Redis метрики |
| **PostgreSQL Database** | `9628` | PostgreSQL мониторинг |

**Шаги:**
```
1. Import → Ввести ID (1860)
2. Load
3. Выбрать datasource: Prometheus
4. Import
```

### **Вариант 2: Скачать JSON файлы**

```bash
# В папке проекта
cd monitoring/grafana-dashboards

# Node Exporter Dashboard
wget https://grafana.com/api/dashboards/1860/revisions/27/download -O node-exporter-full.json

# Redis Dashboard
wget https://grafana.com/api/dashboards/763/revisions/5/download -O redis-dashboard.json

# PostgreSQL Dashboard
wget https://grafana.com/api/dashboards/9628/revisions/7/download -O postgres-dashboard.json

# Перезапустить Grafana
cd ../..
docker-compose restart grafana
```

**Дашборды автоматически загрузятся в Grafana!**

---

## 🔧 Расширенные настройки

### **Изменить retention (хранение метрик):**

```yaml
# docker-compose.yml
prometheus:
  command:
    - '--storage.tsdb.retention.time=90d'  # 90 дней вместо 30
```

### **Изменить scrape interval:**

```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 10s  # По умолчанию 15s
```

---

## ❓ FAQ

### Q: Как проверить, что мониторинг работает?

```bash
# Проверка targets
curl http://localhost:9090/api/v1/targets

# Проверка метрик Node Exporter
curl http://localhost:9100/metrics | grep node_cpu

# Проверка Redis Exporter
curl http://localhost:9121/metrics | grep redis_
```

### Q: Что делать, если target DOWN?

```bash
# Проверьте логи
docker-compose logs prometheus
docker-compose logs node-exporter

# Перезапустите
docker-compose restart prometheus node-exporter
```

### Q: Как отключить мониторинг?

```bash
# Запустить только основные сервисы
docker-compose up -d postgres redis tor n8n
```

---

## 📊 Примеры метрик

### **CPU Usage:**
```promql
rate(node_cpu_seconds_total{mode="idle"}[5m]) * 100
```

### **RAM Usage:**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### **Disk Usage:**
```promql
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

### **Redis Memory:**
```promql
redis_memory_used_bytes
```

### **PostgreSQL Connections:**
```promql
pg_stat_database_numbackends
```

---

## ✅ Чек-лист после запуска

- [ ] Prometheus открывается: http://localhost:9090
- [ ] Все targets UP: http://localhost:9090/targets
- [ ] Grafana открывается: http://localhost:3000
- [ ] Prometheus datasource добавлен в Grafana
- [ ] Дашборды импортированы (1860, 763, 9628)
- [ ] Метрики отображаются на графиках

---

**Статус:** ✅ **Базовый мониторинг готов к использованию!**
