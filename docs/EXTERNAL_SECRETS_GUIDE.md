# External Secrets Integration (Kubernetes)

## Как подключить secure хранение секретов в k8s

### 1. Установка External Secrets Operator (ESO)

```bash
kubectl apply -f https://github.com/external-secrets/external-secrets/releases/latest/download/crds.yaml
kubectl create ns external-secrets
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets
```

### 2. Пример `ExternalSecret` для n8n PostgreSQL:
```yaml
apiVersion: external-secrets.io/v1alpha1
kind: ExternalSecret
metadata:
  name: postgresql-credentials
  namespace: n8n-scraper
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: postgresql-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: prod/n8n/pgsql
        property: username
    - secretKey: password
      remoteRef:
        key: prod/n8n/pgsql
        property: password
```

### 3. Описание полей:
- `secretStoreRef` — ссылка на backend: AWS SecretsManager, GCP, Vault, etc.
- `data` — какие ключи вытянуть в target Secret.

### 4. Как использовать в manifests:
```yaml
env:
  - name: DB_POSTGRESDB_USER
    valueFrom:
      secretKeyRef:
        name: postgresql-credentials
        key: username
  - name: DB_POSTGRESDB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-credentials
        key: password
```

### 5. Полезные ссылки:
- https://external-secrets.io/latest/provider-aws/
- https://external-secrets.io/latest/guides/getting-started/

---

## Sealed Secrets (альтернатива)
- https://github.com/bitnami-labs/sealed-secrets
- CLI: `kubeseal` для шифрования secrets
