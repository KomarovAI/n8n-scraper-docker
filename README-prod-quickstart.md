# N8N Scraper - Production Quickstart

## 🚀 Быстрый деплой в production

### Предварительные требования

- Kubernetes кластер (1.19+)
- Traefik установлен как Ingress Controller
- `kubectl` настроен для доступа к кластеру
- Внешний IP адрес сервера

### Шаг 1: Клонирование репозитория

```bash
git clone https://github.com/KomarovAI/n8n-scraper-workflow.git
cd n8n-scraper-workflow
```

### Шаг 2: Настройка secrets

```bash
# Скопировать пример
cp manifests/secret.yaml.example manifests/secret.yaml

# Отредактировать с вашими паролями
vim manifests/secret.yaml

# Или создать через kubectl
kubectl create secret generic n8n-credentials \
  --from-literal=username='admin' \
  --from-literal=password='your_secure_password' \
  -n n8n-scraper

kubectl create secret generic postgresql-credentials \
  --from-literal=username='n8n' \
  --from-literal=password='your_postgres_password' \
  -n n8n-scraper
```

### Шаг 3: Установка SERVER_IP

```bash
# Замените ${SERVER_IP} на ваш IP в IngressRoute
export SERVER_IP="31.56.39.58"

# Автоматическая замена
sed -i "s/\${SERVER_IP}/$SERVER_IP/g" manifests/ingressroute.yaml

# Проверьте результат
grep "Host(" manifests/ingressroute.yaml
```

### Шаг 4: Деплой

```bash
chmod +x deploy.sh
./deploy.sh
```

### Шаг 5: Проверка

```bash
# Проверить статус подов
kubectl get pods -n n8n-scraper

# Просмотреть логи
kubectl logs -f n8n-scraper-0 -n n8n-scraper

# Проверить StatefulSet
kubectl get statefulset -n n8n-scraper
kubectl get pvc -n n8n-scraper
```

### Шаг 6: Доступ

Откройте в браузере:
```
https://n8n.31.56.39.58.nip.io
```

(Замените IP на ваш)

## 🔒 Безопасность

### GitHub Actions - Только ручной запуск

Все workflows теперь запускаются **только вручную** (через `workflow_dispatch`):

```bash
# Запустить CI/CD
gh workflow run ci.yml -f environment=production

# Запустить Security Scan
gh workflow run security-scan.yml -f scan_type=all
```

Это защищает production от:
- Автоматических деплоев при push
- Случайных запусков
- Несанкционированных изменений

### NetworkPolicy

Разрешены только необходимые соединения:
- Ingress: Traefik → n8n (5678)
- Egress: n8n → PostgreSQL (5432)
- Egress: n8n → Redis (6379)
- Egress: n8n → Internet (80, 443)
- Egress: DNS (53)

### Security Context

```yaml
securityContext:
  privileged: false
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
```

## 🔧 Управление

### Масштабирование

```bash
# Увеличить реплики
kubectl scale statefulset n8n-scraper --replicas=3 -n n8n-scraper

# Уменьшить
kubectl scale statefulset n8n-scraper --replicas=1 -n n8n-scraper
```

### Обновление

```bash
# Обновить образ
kubectl set image statefulset/n8n-scraper \
  n8n=n8nio/n8n:latest \
  -n n8n-scraper

# Удалить под для перезапуска (из-за updateStrategy: OnDelete)
kubectl delete pod n8n-scraper-0 -n n8n-scraper
```

### Бэкап

```bash
# Создать snapshot PVC
kubectl get pvc -n n8n-scraper

# Скопировать данные из пода
kubectl exec -it n8n-scraper-0 -n n8n-scraper -- \
  tar czf /tmp/backup.tar.gz /home/node/.n8n

kubectl cp n8n-scraper/n8n-scraper-0:/tmp/backup.tar.gz ./backup.tar.gz
```

### Восстановление

```bash
# Загрузить бэкап в под
kubectl cp ./backup.tar.gz n8n-scraper/n8n-scraper-0:/tmp/backup.tar.gz

# Распаковать
kubectl exec -it n8n-scraper-0 -n n8n-scraper -- \
  tar xzf /tmp/backup.tar.gz -C /

# Перезапустить
kubectl delete pod n8n-scraper-0 -n n8n-scraper
```

## 🧹 Удаление

```bash
chmod +x uninstall.sh
./uninstall.sh
```

**Внимание:** Это удалит все данные включая PVC!

## 📊 Мониторинг

```bash
# Проверка здоровья
kubectl exec -it n8n-scraper-0 -n n8n-scraper -- \
  curl http://localhost:5678/healthz

# Метрики Prometheus
kubectl port-forward n8n-scraper-0 5678:5678 -n n8n-scraper
curl http://localhost:5678/metrics

# Логи
kubectl logs -f n8n-scraper-0 -n n8n-scraper
```

## 🔗 Ссылки

- [README.md](README.md) - Полная документация
- [SECURITY.md](SECURITY.md) - Руководство по безопасности
- [3xui-k8s-statefulset](https://github.com/KomarovAI/3xui-k8s-statefulset) - Референсная архитектура

---

**Создано по принципам 3xui-k8s-statefulset**
