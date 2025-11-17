# 🚀 Production Deployment Checklist - V3 Fixes

## 📅 Pre-Deployment

### Infrastructure

- [ ] **Redis instance running**
  - URL: `redis://redis:6379`
  - Test: `redis-cli ping` returns `PONG`
  - Health: `kubectl get pods -l app=redis`

- [ ] **PostgreSQL accessible**
  - Version: 14+
  - Database: `n8n_db`
  - User: `n8n` with CREATE/ALTER permissions
  - Test: `psql -U n8n -d n8n_db -c 'SELECT version();'`

- [ ] **Jaeger (optional, for tracing)**
  - Endpoint: `http://jaeger:14268/api/traces`
  - UI: `http://jaeger:16686`
  - Test: `curl http://jaeger:14268/api/traces`

- [ ] **Prometheus (optional, for metrics)**
  - Scrape config: `http://n8n-scraper:5678/metrics`
  - Test: `curl http://n8n-scraper:5678/metrics`

### Secrets & Config

- [ ] **Firecrawl API Key configured**
  ```bash
  kubectl create secret generic n8n-credentials \
    --from-literal=firecrawl-api-key='fc-xxxxx' \
    -n n8n-scraper
  ```

- [ ] **GitHub API Token configured**
  ```bash
  kubectl create secret generic github-credentials \
    --from-literal=github-token='ghp_xxxxx' \
    -n n8n-scraper
  ```

- [ ] **IP Whitelist configured**
  ```bash
  # Add to ConfigMap or env vars
  WEBHOOK_IP_WHITELIST=1.2.3.4,5.6.7.8
  ```

- [ ] **Rate Limit configured**
  ```bash
  RATE_LIMIT_MAX=10  # requests per 60 seconds
  ```

---

## 🛠️ Build & Test

### Docker Image

- [ ] **Build enhanced image**
  ```bash
  docker build -f Dockerfile.n8n-enhanced -t n8n-scraper:v3.0.0 .
  ```

- [ ] **Tag for registry**
  ```bash
  docker tag n8n-scraper:v3.0.0 your-registry/n8n-scraper:v3.0.0
  docker push your-registry/n8n-scraper:v3.0.0
  ```

- [ ] **Verify dependencies in image**
  ```bash
  docker run --rm n8n-scraper:v3.0.0 npm list | grep -E '(cheerio|axios|puppeteer-cluster|prom-client)'
  ```

### Database Migration

- [ ] **Backup current database**
  ```bash
  kubectl exec -it postgresql-0 -n n8n-scraper -- \
    pg_dump -U n8n n8n_db > backup_$(date +%Y%m%d).sql
  ```

- [ ] **Run migration (dry-run first)**
  ```bash
  # Dry-run
  kubectl exec -it postgresql-0 -n n8n-scraper -- \
    psql -U n8n -d n8n_db -f /migrations/001_create_scraped_data_table.sql --dry-run
  
  # Actual run
  kubectl exec -it postgresql-0 -n n8n-scraper -- \
    psql -U n8n -d n8n_db -f /migrations/001_create_scraped_data_table.sql
  ```

- [ ] **Verify schema**
  ```sql
  \d scraped_data
  \di scraped_data*
  SELECT * FROM pg_indexes WHERE tablename = 'scraped_data';
  ```

### E2E Tests

- [ ] **Run E2E test suite**
  ```bash
  export N8N_BASE_URL=http://localhost:5678
  export SCRAPER_API_KEY=test-api-key
  node tests/e2e/workflow-test.js
  ```

- [ ] **All 8 tests passing**
  - Simple scrape
  - Batch scrape
  - Quality check
  - SSRF protection
  - Rate limiting
  - Invalid auth
  - Workflow stats
  - Fallback chain

---

## 🚀 Deployment

### Kubernetes Rollout

- [ ] **Update StatefulSet image**
  ```yaml
  # manifests/statefulset.yaml
  spec:
    template:
      spec:
        containers:
        - name: n8n
          image: your-registry/n8n-scraper:v3.0.0
  ```

- [ ] **Add new environment variables**
  ```yaml
  env:
    - name: REDIS_URL
      value: "redis://redis:6379"
    - name: WEBHOOK_IP_WHITELIST
      value: "1.2.3.4,5.6.7.8"
    - name: RATE_LIMIT_MAX
      value: "10"
    - name: FIRECRAWL_API_KEY
      valueFrom:
        secretKeyRef:
          name: n8n-credentials
          key: firecrawl-api-key
    - name: OTEL_TRACING_ENABLED
      value: "true"
    - name: JAEGER_ENDPOINT
      value: "http://jaeger:14268/api/traces"
  ```

- [ ] **Deploy to Kubernetes**
  ```bash
  kubectl apply -f manifests/namespace.yaml
  kubectl apply -f manifests/secret.yaml
  kubectl apply -f manifests/postgresql.yaml
  kubectl apply -f manifests/redis.yaml
  kubectl apply -f manifests/statefulset.yaml
  kubectl apply -f manifests/service.yaml
  kubectl apply -f manifests/ingressroute.yaml
  kubectl apply -f manifests/networkpolicy.yaml
  ```

- [ ] **Watch rollout**
  ```bash
  kubectl rollout status statefulset/n8n-scraper -n n8n-scraper
  ```

- [ ] **Check pod health**
  ```bash
  kubectl get pods -n n8n-scraper
  kubectl logs -f n8n-scraper-0 -n n8n-scraper
  ```

---

## ✅ Verification

### Functional Tests

- [ ] **N8N accessible**
  ```bash
  curl -I https://n8n.31.56.39.58.nip.io
  ```

- [ ] **Webhook endpoint responding**
  ```bash
  curl -X POST https://n8n.31.56.39.58.nip.io/webhook/scrape \
    -H "Authorization: Bearer ${SCRAPER_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"urls": ["https://example.com"]}'
  ```

- [ ] **Rate limiting active**
  ```bash
  # Send 15 requests rapidly
  for i in {1..15}; do 
    curl -X POST https://n8n.31.56.39.58.nip.io/webhook/scrape \
      -H "Authorization: Bearer ${SCRAPER_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"urls": ["https://example.com"]}' &
  done
  # Should see 429 responses
  ```

- [ ] **SSRF protection active**
  ```bash
  curl -X POST https://n8n.31.56.39.58.nip.io/webhook/scrape \
    -H "Authorization: Bearer ${SCRAPER_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"urls": ["http://localhost:8080"]}'
  # Should return 400/403
  ```

- [ ] **Quality check working**
  - Scrape site with < 500 chars → should trigger fallback
  - Scrape normal site → should pass

### Monitoring

- [ ] **Prometheus metrics available**
  ```bash
  curl http://n8n-scraper:5678/metrics | grep n8n_
  ```

- [ ] **Metrics showing data**
  ```bash
  # Check specific metrics
  curl -s http://n8n-scraper:5678/metrics | grep -E '(workflow_executions|scrape_requests|quality_check)'
  ```

- [ ] **Jaeger traces visible**
  - Open: http://jaeger:16686
  - Search for service: `n8n-scraper-workflow`
  - Verify traces appear

- [ ] **Grafana dashboard (optional)**
  - Import dashboard
  - Connect to Prometheus datasource
  - Verify panels showing data

### Database

- [ ] **Data being saved**
  ```sql
  SELECT COUNT(*) FROM scraped_data;
  SELECT runner, COUNT(*) FROM scraped_data GROUP BY runner;
  ```

- [ ] **Indexes being used**
  ```sql
  EXPLAIN ANALYZE SELECT * FROM scraped_data WHERE url = 'https://example.com';
  -- Should show "Index Scan using idx_scraped_url"
  ```

- [ ] **Stats view working**
  ```sql
  SELECT * FROM scraped_data_stats;
  ```

---

## 🚨 Rollback Plan

### If issues detected:

- [ ] **Rollback StatefulSet**
  ```bash
  kubectl rollout undo statefulset/n8n-scraper -n n8n-scraper
  ```

- [ ] **Rollback database migration**
  ```bash
  kubectl exec -it postgresql-0 -n n8n-scraper -- \
    psql -U n8n -d n8n_db < backup_$(date +%Y%m%d).sql
  ```

- [ ] **Restore old image**
  ```bash
  kubectl set image statefulset/n8n-scraper \
    n8n=n8nio/n8n:latest -n n8n-scraper
  ```

---

## 📊 Post-Deployment Monitoring

### First 24 Hours

- [ ] **Monitor error rate** (should be < 5%)
  ```promql
  rate(n8n_workflow_executions_total{status="failed"}[5m])
  ```

- [ ] **Monitor latency** (P95 should be < 30s)
  ```promql
  histogram_quantile(0.95, rate(n8n_workflow_duration_seconds_bucket[5m]))
  ```

- [ ] **Monitor rate limiting** (check for abuse)
  ```promql
  sum(rate(n8n_rate_limit_exceeded_total[5m])) by (client_ip)
  ```

- [ ] **Monitor circuit breaker state** (should be mostly CLOSED)
  ```promql
  n8n_circuit_breaker_state
  ```

- [ ] **Check logs for errors**
  ```bash
  kubectl logs -f n8n-scraper-0 -n n8n-scraper | grep -i error
  ```

### First Week

- [ ] **Review Jaeger traces** for slow operations
- [ ] **Analyze Prometheus metrics** for patterns
- [ ] **Check database growth** and adjust storage if needed
- [ ] **Validate IP whitelist** effectiveness
- [ ] **Tune rate limits** based on usage patterns

---

## 📝 Sign-Off

**Deployed by**: _________________  
**Date**: _________________  
**Version**: v3.0.0  
**Environment**: Production  

**Verification**:
- [ ] All functional tests passed
- [ ] All monitoring systems operational
- [ ] Database migration successful
- [ ] Rollback plan tested and documented
- [ ] Team notified of deployment

**Notes**:

---

**Next Steps**:
1. Monitor for 24 hours
2. Collect feedback from users
3. Fine-tune rate limits and quality thresholds
4. Plan next optimization cycle
