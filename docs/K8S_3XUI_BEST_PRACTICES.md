# 3xui-bases Production K8S Best Practices for n8n-scraper

## Структура manifests для stateful workload

manifests/
├── namespace.yaml         # Namespace
├── statefulset-n8n.yaml   # N8N core app StatefulSet + Service + PVC
├── statefulset-pg.yaml    # PostgreSQL StatefulSet + Service + PVC
├── statefulset-redis.yaml # Redis StatefulSet + Service + PVC
├── networkpolicy.yaml     # Всегда отдельный файл
├── ingressroute.yaml      # Traefik or other ingress
├── cronjob-pg-backup.yaml # Авто-бэкап PostgreSQL в S3
├── secret-n8n-creds.yaml  # Пример секрета через ExternalSecret
...

## K8s manifest patterns:
### StatefulSet (пример n8n):
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: n8n
  namespace: n8n-scraper
spec:
  replicas: 2
  serviceName: n8n-headless
  selector:
    matchLabels:
      app: n8n
  template:
    metadata:
      labels:
        app: n8n
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      initContainers:
        - name: wait-for-pg
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              until nc -z postgresql.n8n-scraper.svc.cluster.local 5432; do sleep 2; done
        - name: wait-for-redis
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              until nc -z redis.n8n-scraper.svc.cluster.local 6379; do sleep 2; done
      containers:
        - name: n8n
          image: n8nio/n8n:1.15.0
          envFrom:
            - secretRef:
                name: n8n-creds
          ports:
            - name: web
              containerPort: 5678
          resources:
            limits:
              cpu: 1200m
              memory: 1.5Gi
            requests:
              cpu: 400m
              memory: 768Mi
          livenessProbe:
            httpGet:
              path: /
              port: 5678
            initialDelaySeconds: 60
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: 5678
            initialDelaySeconds: 30
            periodSeconds: 10
          volumeMounts:
            - name: n8n-data
              mountPath: /home/node/.n8n
  volumeClaimTemplates:
    - metadata:
        name: n8n-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 10Gi
```

### Headless Service (общий паттерн):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: n8n-headless
  namespace: n8n-scraper
spec:
  clusterIP: None
  selector:
    app: n8n
  ports:
    - name: web
      port: 5678
      targetPort: 5678
```

### NetworkPolicy (baseline):
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: n8n-scraper
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
          except:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
            - 127.0.0.0/8
            - 169.254.0.0/16
    - to:
        - namespaceSelector: { matchLabels: { name: n8n-scraper } }
```

### Example CronJob для backup PostgreSQL на S3
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pg-backup-s3
  namespace: n8n-scraper
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15
              envFrom:
                - secretRef:
                    name: postgresql-credentials
              env:
                - name: S3_BUCKET
                  value: n8n-backups-prod
                - name: AWS_ACCESS_KEY_ID
                  valueFrom:
                    secretKeyRef:
                      name: aws-credentials
                      key: access_key
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      name: aws-credentials
                      key: secret_key
              command:
                - sh
                - -c
                - |
                  pg_dump -U $DB_USER -h $DB_HOST $DB_NAME | \
                  aws s3 cp - s3://$S3_BUCKET/backup-$(date +%Y-%m-%d).sql
          restartPolicy: OnFailure
```

---
## Скрипты deploy/uninstall обновить — см. deploy.sh/uninstall.sh паттерн 3xui

---
## Day-2 Ops Checklist (из 3xui опыта):
- Бэкапы расписаны через CronJob
- HA PostgreSQL — через Patroni (Helm chart, link в README)
- Prometheus + Grafana ServiceMonitor для всех metrics
- Обновления только через helm/kustomize patch
- Structured logging в stdout (готово для Loki)

---
## См. подробный deploy-ready пример в каждом приложении на: https://github.com/KomarovAI/3xui-k8s-statefulset

---
