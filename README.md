# N8N Scraper - Kubernetes StatefulSet Deployment

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Production Ready](https://img.shields.io/badge/production-ready-green.svg)](https://github.com/KomarovAI/n8n-scraper-workflow)
[![Audited](https://img.shields.io/badge/audited-2025--11--18-blue.svg)](AUDIT_REPORT.md)

Enterprise-grade web scraping platform для Kubernetes с использованием **StatefulSet** и интеграцией с Traefik.

> 🔍 **[Отчёт аудита](AUDIT_REPORT.md)** - Все критические проблемы исправлены, 15+ оптимизаций применено

## 🎯 Ключевые особенности

- **StatefulSet** вместо Deployment - стабильная идентичность подов
- **PostgreSQL + Redis** StatefulSets - полный stack в K8s
- **Headless Service** - прямое подключение к подам
- **Автоматический HTTPS** через Traefik + Let's Encrypt
- **Минималистичная структура** - только необходимые манифесты
- **Production-ready** - NetworkPolicy, Init Containers, Resource Limits
- **Простой деплой** - `./deploy.sh` и готово

## 🚀 Быстрый старт

### Предварительные требования

- Kubernetes кластер (1.19+)
- Traefik установлен как Ingress Controller
- `kubectl` настроен для доступа к кластеру

### Установка

```bash
# 1. Клонируем репозиторий
git clone https://github.com/KomarovAI/n8n-scraper-workflow.git
cd n8n-scraper-workflow

# 2. Создаём secrets
cp manifests/secret.yaml.example manifests/secret.yaml
# Отредактируйте manifests/secret.yaml с вашими паролями

# 3. Устанавливаем ваш SERVER_IP
export SERVER_IP="31.56.39.58"  # Ваш IP сервера

# 4. Деплоим
chmod +x deploy.sh
./deploy.sh
```

### Проверка

```bash
# Проверить статус подов
kubectl get pods -n n8n-scraper

# Просмотреть логи
kubectl logs -f n8n-scraper-0 -n n8n-scraper

# Проверить StatefulSet
kubectl get statefulset -n n8n-scraper
kubectl get pvc -n n8n-scraper
```

### Доступ

После деплоя N8N будет доступен по адресу:
```
https://n8n.${SERVER_IP}.nip.io
```

Пример: `https://n8n.31.56.39.58.nip.io`

## 📚 Структура проекта

```
n8n-scraper-workflow/
├── manifests/              # Kubernetes манифесты
│   ├── namespace.yaml       # Namespace
│   ├── statefulset.yaml     # N8N StatefulSet + Headless Service
│   ├── postgresql.yaml      # PostgreSQL StatefulSet
│   ├── redis.yaml           # Redis StatefulSet
│   ├── service.yaml         # External Service для Traefik
│   ├── ingressroute.yaml    # Traefik IngressRoute с HTTPS
│   ├── networkpolicy.yaml   # Сетевые политики
│   └── secret.yaml.example  # Пример secrets
├── deploy.sh               # Скрипт деплоя
├── uninstall.sh            # Скрипт удаления
├── AUDIT_REPORT.md        # 🔍 Отчёт аудита
├── docker-compose.yml      # Для локальной разработки
└── docs/                   # Дополнительная документация
```

## 🔒 Безопасность

### NetworkPolicy
Разрешены только необходимые соединения:
- Ingress от Traefik на порт 5678
- Egress к PostgreSQL (5432)
- Egress к Redis (6379)
- Egress для scraping (80, 443) с CIDR filtering
- DNS резолюция
- Исключены локальные сети и cloud metadata endpoints

### Security Context
- `runAsNonRoot: true`
- `runAsUser: 1000`
- `capabilities: drop ALL`
- `privileged: false`

### Init Containers
- Проверка доступности PostgreSQL перед запуском N8N

### Secrets Management
Все секреты хранятся в Kubernetes Secrets:
```bash
kubectl create secret generic n8n-credentials \
  --from-literal=username='admin' \
  --from-literal=password='secure_password' \
  -n n8n-scraper
```

## 🔧 Интеграция с Traefik

### Автоматический HTTPS

Traefik автоматически выдаёт SSL-сертификаты от Let's Encrypt:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: n8n-scraper
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`n8n.${SERVER_IP}.nip.io`)
      kind: Rule
      services:
        - name: n8n-scraper-external
          port: 5678
  tls:
    certResolver: letsencrypt
```

### Архитектура

```
Интернет
   ↓
DNS: n8n.${SERVER_IP}.nip.io → ${SERVER_IP}
   ↓
Traefik (порты 80/443)
   ↓ Let's Encrypt SSL
IngressRoute → n8n-scraper-external Service (порт 5678)
   ↓
n8n-scraper StatefulSet (Init Container → N8N)
   ↓
PostgreSQL + Redis StatefulSets
```

## 💾 Persistent Storage

StatefulSet использует `volumeClaimTemplates` для автоматического создания PVC:

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: local-path
      resources:
        requests:
          storage: 10Gi  # N8N
          # 5Gi PostgreSQL, 1Gi Redis
```

Каждый под получает свой собственный PVC:
- `data-n8n-scraper-0`
- `data-postgresql-0`
- `data-redis-0`

## 🔄 Масштабирование

```bash
# Увеличить количество реплик
kubectl scale statefulset n8n-scraper --replicas=3 -n n8n-scraper

# Проверить статус
kubectl get pods -n n8n-scraper
```

## 🧹 Очистка

```bash
# Полное удаление всех ресурсов
chmod +x uninstall.sh
./uninstall.sh
```

**Внимание**: Это удалит все данные включая PVC!

## 📊 Мониторинг

### Проверка здоровья

```bash
# Liveness probe
kubectl exec -it n8n-scraper-0 -n n8n-scraper -- curl http://localhost:5678/

# Логи
kubectl logs -f n8n-scraper-0 -n n8n-scraper

# Описание пода
kubectl describe pod n8n-scraper-0 -n n8n-scraper
```

### Метрики N8N

N8N экспортирует метрики Prometheus на `/metrics`:
```bash
kubectl port-forward n8n-scraper-0 5678:5678 -n n8n-scraper
curl http://localhost:5678/metrics
```

## 🔧 Troubleshooting

### Pod не запускается

```bash
# Проверить события
kubectl get events -n n8n-scraper --sort-by='.lastTimestamp'

# Проверить describe
kubectl describe pod n8n-scraper-0 -n n8n-scraper

# Проверить логи
kubectl logs n8n-scraper-0 -n n8n-scraper --previous
```

### Проблемы с PVC

```bash
# Проверить PVC
kubectl get pvc -n n8n-scraper

# Проверить PV
kubectl get pv

# Удалить PVC (осторожно!)
kubectl delete pvc data-n8n-scraper-0 -n n8n-scraper
```

### HTTPS не работает

```bash
# Проверить IngressRoute
kubectl describe ingressroute n8n-scraper -n n8n-scraper

# Проверить Traefik логи
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# Проверить сертификаты
kubectl get certificates -A
```

## 📚 Дополнительная документация

- **[🔍 AUDIT_REPORT.md](AUDIT_REPORT.md)** - Полный отчёт аудита (9 критических проблем исправлено)
- [SECURITY.md](SECURITY.md) - Руководство по безопасности
- [README-prod-quickstart.md](README-prod-quickstart.md) - Быстрый старт в production
- [docker-compose.yml](docker-compose.yml) - Локальная разработка
- [docs/](docs/) - Расширенная документация

## 🔗 Ссылки

- [3xui-k8s-statefulset](https://github.com/KomarovAI/3xui-k8s-statefulset) - Референсная архитектура
- [n8n Documentation](https://docs.n8n.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## 📝 Лицензия

MIT License - см. [LICENSE](LICENSE)

---

**Built with ❤️ by KomarovAI**
