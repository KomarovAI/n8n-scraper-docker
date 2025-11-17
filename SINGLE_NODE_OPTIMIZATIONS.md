# Single-Node Cluster Optimizations

Дата: 18 ноября 2025  
Статус: ✅ Оптимизировано для 1 master node

## 🎯 Цель

Проект оптимизирован для разворачивания на **одной master node** с минимальными ресурсами без потери функциональности.

---

## ✅ Применённые оптимизации

### 1. **Tolerations для Master Node**

Добавлены во все StatefulSet:

```yaml
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
```

**Почему важно:**  
Master node по умолчанию имеет taint `NoSchedule`, который запрещает запуск workload-подов. Tolerations разрешают запуск на master.

**Применено к:**
- N8N StatefulSet
- PostgreSQL StatefulSet
- Redis StatefulSet

---

### 2. **Уменьшенные Resource Limits**

#### N8N
```yaml
# Было:
limits:
  memory: 1Gi
  cpu: 1000m
requests:
  memory: 512Mi
  cpu: 250m

# Стало:
limits:
  memory: 768Mi   # -23%
  cpu: 800m       # -20%
requests:
  memory: 384Mi   # -25%
  cpu: 200m       # -20%
```

#### PostgreSQL
```yaml
# Было:
limits:
  memory: 512Mi
  cpu: 500m
requests:
  memory: 256Mi
  cpu: 100m

# Стало:
limits:
  memory: 384Mi   # -25%
  cpu: 400m       # -20%
requests:
  memory: 192Mi   # -25%
  cpu: 100m       # без изменений
```

#### Redis
```yaml
# Было:
limits:
  memory: 256Mi
  cpu: 200m
requests:
  memory: 128Mi
  cpu: 50m

# Стало:
limits:
  memory: 192Mi   # -25%
  cpu: 150m       # -25%
requests:
  memory: 96Mi    # -25%
  cpu: 50m        # без изменений
```

**Почему важно:**  
Na single-node кластере важно не перегружать ноду. Уменьшенные limits позволяют запустить все поды на одной ноде.

---

### 3. **Уменьшенные Storage Requests**

#### PVC размеры
```yaml
# N8N
storage: 5Gi      # было 10Gi (-50%)

# PostgreSQL
storage: 2Gi      # было 5Gi (-60%)

# Redis
storage: 512Mi    # было 1Gi (-50%)
```

**Общий storage:**  
- Было: 16Gi  
- Стало: **7.5Gi** (-53%)

**Почему важно:**  
Na single-node часто ограниченное дисковое пространство. Для production достаточно 7.5Gi.

---

### 4. **Redis: maxmemory ограничение**

```yaml
command:
  - redis-server
  - --maxmemory
  - "128mb"           # Жёсткое ограничение памяти
  - --maxmemory-policy
  - "allkeys-lru"     # Удалять старые ключи
```

**Почему важно:**  
Защита от OOM (Out Of Memory) на single-node. Redis не сможет занять больше 128mb.

---

### 5. **StorageClass: local-path**

Создан `manifests/storageclass.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
reclaimPolicy: Retain  # Не удалять данные!
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**Особенности:**
- `reclaimPolicy: Retain` - данные не удаляются при удалении PVC
- `WaitForFirstConsumer` - PV создаётся только когда под запланирован
- `allowVolumeExpansion: true` - можно увеличить размер позже

---

### 6. **Обновлённый deploy.sh**

Добавлено:
- Деплой StorageClass (до secrets)
- Информация о Single-Node Mode
- Подсчёт общего storage usage

```bash
echo "ℹ️  Single-Node Cluster Mode"
echo "   - All pods will run on master node"
echo "   - Using local-path storage"
echo "   - Optimized resource limits"
```

---

## 📊 Итоговые ресурсы на Single-Node

### CPU
```
N8N:        200m requests, 800m limits
PostgreSQL: 100m requests, 400m limits
Redis:       50m requests, 150m limits
-------------------------------------------
ИТОГО:     350m requests, 1350m limits
```

**Минимальный рекомендуемый CPU:** 2 cores

### Memory
```
N8N:        384Mi requests,  768Mi limits
PostgreSQL: 192Mi requests,  384Mi limits
Redis:       96Mi requests,  192Mi limits
-------------------------------------------
ИТОГО:     672Mi requests, 1344Mi limits
```

**Минимальная рекомендуемая RAM:** 2Gi  
**Рекомендуемая RAM:** 4Gi (с запасом для Kubernetes)

### Storage
```
N8N:        5Gi
PostgreSQL: 2Gi
Redis:      512Mi
-------------------------------------------
ИТОГО:     ~7.5Gi
```

**Минимальный рекомендуемый диск:** 20Gi  
**Рекомендуемый диск:** 40Gi+

---

## 💻 Рекомендуемые характеристики сервера

### Минимальные
- **CPU:** 2 cores
- **RAM:** 2Gi
- **Disk:** 20Gi SSD

### Рекомендуемые (для production)
- **CPU:** 4 cores
- **RAM:** 4Gi
- **Disk:** 40Gi+ SSD

### Примеры VPS
- **Contabo VPS M:** 4 vCPU, 8Gi RAM, 200Gi SSD - 8.99€/мес
- **Hetzner CPX21:** 3 vCPU, 4Gi RAM, 80Gi SSD - 7.18€/мес
- **DigitalOcean:** 2 vCPU, 4Gi RAM, 80Gi SSD - $24/мес

---

## ⚡ Особенности Single-Node

### Плюсы
✅ Простота управления  
✅ Низкие требования к ресурсам  
✅ Минимальная стоимость  
✅ Нет сетевых задержек между нодами  

### Минусы
⚠️ Нет High Availability  
⚠️ Нет горизонтального масштабирования  
⚠️ Single Point of Failure  

### Когда использовать
✅ Dev/Staging окружения  
✅ Малые production проекты (<1000 req/day)  
✅ Личные проекты  
✅ Ограниченный бюджет  

---

## 🛠️ Дальнейшая оптимизация

Если нужно ещё больше сэкономить:

1. **Использовать SQLite вместо PostgreSQL**
   - Экономия: ~200Mi RAM, 2Gi disk
   - Но хуже для production

2. **Убрать Redis**
   - Экономия: ~100Mi RAM, 512Mi disk
   - Но потеря rate limiting/caching

3. **Использовать k3s вместо Kubernetes**
   - Экономия: ~500Mi RAM
   - Легковесный Kubernetes

---

## ✅ Заключение

Проект полностью оптимизирован для **single-node кластера**:

✅ Tolerations для master node  
✅ Уменьшенные resource limits (-20-25%)  
✅ Уменьшенные storage requests (-50%)  
✅ local-path StorageClass  
✅ Redis maxmemory ограничение  

**Минимальный сервер:** 2 CPU, 2Gi RAM, 20Gi SSD  
**Рекомендуемый:** 4 CPU, 4Gi RAM, 40Gi+ SSD

---

**Дата:** 18.11.2025  
**Автор:** KomarovAI  
**Статус:** ✅ OPTIMIZED FOR SINGLE-NODE
