# Deployment Guide

## Prerequisites

- Kubernetes 1.28+ with Calico or Cilium CNI
- PostgreSQL 14+ (for N8N data)
- Redis 7+ (for caching and rate limiting)
- GitHub Personal Access Token with `repo` and `actions` scopes
- Firecrawl API key (optional, for fallback)

## Step-by-Step Deployment

### 1. Prepare Secrets

```bash
# Create namespace
kubectl create namespace n8n

# N8N credentials
kubectl create secret generic n8n-credentials \
  --from-literal=username=admin \
  --from-literal=password='<STRONG_PASSWORD>' \
  -n n8n

# PostgreSQL credentials
kubectl create secret generic postgresql-credentials \
  --from-literal=username=n8n \
  --from-literal=password='<DB_PASSWORD>' \
  -n n8n

# GitHub token
kubectl create secret generic github-token \
  --from-literal=token='<GITHUB_PAT>' \
  -n n8n

# Firecrawl API key (optional)
kubectl create secret generic firecrawl-api \
  --from-literal=key='<API_KEY>' \
  -n n8n
```

### 2. Deploy Redis

```bash
kubectl apply -f k8s/redis.yaml

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app=redis -n n8n --timeout=120s

# Test connection
kubectl run redis-test --rm -it --image=redis:7-alpine -n n8n -- redis-cli -h redis ping
```

### 3. Deploy N8N

```bash
# Apply deployment
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Apply autoscaling
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml

# Apply network policy
kubectl apply -f k8s/networkpolicy.yaml

# Apply ingress
kubectl apply -f k8s/ingress.yaml

# Check status
kubectl get pods -n n8n -w
```

### 4. Configure N8N

1. Access N8N UI: `https://n8n.your-domain.com`
2. Login with credentials from step 1
3. Import workflow: `workflows/workflow-scraper-secured.json`
4. Configure credentials:
   - Header Auth: Set API key for webhook
   - GitHub API: Add personal access token
   - PostgreSQL: Connection string
   - Redis: `redis://redis.n8n.svc.cluster.local:6379`

### 5. Configure GitHub Actions

Update workflow secrets in your GitHub repository:

```bash
gh secret set GITHUB_TOKEN --body "<YOUR_PAT>"
gh secret set REDIS_URL --body "<REDIS_CONNECTION_STRING>"
```

### 6. Deploy Monitoring

```bash
# Apply Prometheus rules
kubectl apply -f monitoring/prometheus-rules.yaml -n monitoring

# Verify alerts
kubectl get prometheusrules -n monitoring
```

### 7. Verify Deployment

```bash
# Test webhook
curl -X POST https://n8n.your-domain.com/webhook/scrape \
  -H "X-API-Key: your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "selector": "article"
  }'

# Check logs
kubectl logs -f deployment/n8n-scraper -n n8n

# Check HPA
kubectl get hpa -n n8n

# Check metrics
kubectl top pods -n n8n
```

## Troubleshooting

### Pods not starting

```bash
# Check events
kubectl describe pod <pod-name> -n n8n

# Check logs
kubectl logs <pod-name> -n n8n --previous

# Common issues:
# - Missing secrets: Create as per step 1
# - Image pull error: Check network connectivity
# - Resource limits: Adjust in deployment.yaml
```

### Redis connection failed

```bash
# Test from N8N pod
kubectl exec -it deployment/n8n-scraper -n n8n -- sh
wget -O- redis://redis:6379

# Check NetworkPolicy
kubectl get netpol -n n8n

# Temporarily disable to debug
kubectl delete netpol n8n-scraper-netpol -n n8n
```

### GitHub Actions not triggering

```bash
# Check workflow exists
gh workflow list

# Check permissions
gh api /repos/{owner}/{repo}/actions/permissions

# Manual trigger
gh workflow run nodriver-batch-secured.yml \
  -f urls='[{"url":"https://example.com"}]' \
  -f batchId=test-123
```

### High failure rate

```bash
# Check Prometheus alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090/alerts

# Check scraper logs
kubectl logs -f deployment/n8n-scraper -n n8n | grep ERROR

# Common causes:
# - Rate limiting: Increase delays
# - Bot detection: Sites have enhanced protection
# - Network issues: Check egress rules
```

## Performance Tuning

### Increase throughput

```yaml
# In k8s/hpa.yaml
spec:
  maxReplicas: 20  # Increase from 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 60  # Decrease from 70
```

### Reduce latency

```yaml
# In k8s/deployment.yaml
resources:
  requests:
    memory: "1Gi"  # Increase from 512Mi
    cpu: "1000m"   # Increase from 500m
```

### Optimize Redis

```yaml
# In k8s/redis.yaml
data:
  redis.conf: |
    maxmemory 2gb        # Increase from 512mb
    maxmemory-policy allkeys-lfu  # Change from lru
```

## Security Hardening

### Enable Pod Security Standards

```bash
kubectl label namespace n8n \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### Rotate secrets regularly

```bash
# Every 90 days
kubectl create secret generic n8n-credentials \
  --from-literal=password='<NEW_PASSWORD>' \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new secrets
kubectl rollout restart deployment/n8n-scraper -n n8n
```

### Enable audit logging

```bash
# Add to N8N deployment
env:
- name: N8N_LOG_LEVEL
  value: "debug"
- name: N8N_LOG_OUTPUT
  value: "json"
```

## Backup and Recovery

### Backup PostgreSQL

```bash
# Daily backup
kubectl exec -it postgresql-0 -n n8n -- \
  pg_dump -U n8n n8n > backup-$(date +%Y%m%d).sql

# Restore
kubectl exec -i postgresql-0 -n n8n -- \
  psql -U n8n n8n < backup-20251116.sql
```

### Backup Redis (optional)

```bash
kubectl exec -it redis-0 -n n8n -- redis-cli BGSAVE
kubectl cp n8n/redis-0:/data/dump.rdb ./redis-backup.rdb
```

## Scaling Considerations

| Load | Replicas | CPU/Pod | Memory/Pod | Redis |
|------|----------|---------|------------|-------|
| Light (<100 req/day) | 2 | 500m | 512Mi | 256Mi |
| Medium (<1000 req/day) | 5 | 1000m | 1Gi | 512Mi |
| Heavy (<10k req/day) | 10 | 2000m | 2Gi | 2Gi |
| Very Heavy (>10k req/day) | 20 | 4000m | 4Gi | 4Gi |
