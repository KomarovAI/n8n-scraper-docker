# Troubleshooting FAQ

> **Purpose**: Quick solutions to common problems for AI assistants and developers.

---

## 🔴 Critical Issues

### Webhook Returns HTTP 500

**Symptoms**:
- Webhook endpoint responds but returns 500 error
- n8n logs show "Error in workflow"
- Tests failing consistently

**Root Cause**: Missing or incorrect `Respond to Webhook` node

**Solution**:

1. **Add explicit Respond node**:
```json
{
  "name": "Respond to Webhook",
  "type": "n8n-nodes-base.respondToWebhook",
  "parameters": {
    "respondWith": "json",
    "responseBody": "={{ $json }}"
  }
}
```

2. **Set correct responseMode**:
```json
{
  "name": "Webhook",
  "parameters": {
    "responseMode": "responseNode"  // NOT "lastNode"
  }
}
```

3. **Ensure all paths lead to Respond node**:
```
Success Branch → Respond
Error Branch → Respond
```

**Reference**: `AUDIT-REPORT.md` section "Исправление 1"

---

### Authentication Failed (n8n 1.0+)

**Symptoms**:
- "Unauthorized" errors
- Basic Auth not working
- Cannot import workflows

**Root Cause**: n8n 1.0+ removed Basic Auth support

**Solution**:

1. **Remove Basic Auth**:
```bash
# ❌ OLD (deprecated)
curl -u user:pass http://localhost:5678/api/...

# ✅ NEW (API Key)
curl -H "X-N8N-API-KEY: your-key" http://localhost:5678/api/...
```

2. **Create API Key manually**:
   - Open n8n UI: http://localhost:5678
   - Go to Settings → API
   - Click "Create API Key"
   - Copy key to `N8N_API_KEY` secret

3. **Update environment variables**:
```bash
N8N_USER=admin@example.com        # Owner email
N8N_PASSWORD=secure_password      # Owner password
N8N_API_KEY=n8n_api_xxxxx        # Manual API key
```

**Reference**: `docs/CRITICAL_FIXES_2025-11-30.md`

---

## 🟠 Service Issues

### n8n Container Won't Start

**Check**:
```bash
docker compose logs n8n
```

**Common causes**:

1. **PostgreSQL not ready**
```bash
# Check PostgreSQL
docker compose exec postgres pg_isready -U n8n_user

# If fails, restart:
docker compose restart postgres
sleep 5
docker compose restart n8n
```

2. **Missing environment variables**
```bash
# Verify .env file exists
ls -la .env

# Check required variables
grep -E "POSTGRES_PASSWORD|N8N_PASSWORD" .env
```

3. **Port conflict**
```bash
# Check if port 5678 is in use
sudo lsof -i :5678

# Stop conflicting process or change port in docker-compose.yml
```

---

### ML Service Not Responding

**Check**:
```bash
docker compose logs ml-service
curl http://localhost:8000/health
```

**Common causes**:

1. **Ollama model not loaded**
```bash
# Check Ollama
docker compose exec ollama ollama list

# Pull model if missing
docker compose exec ollama ollama pull llama3.2:3b

# Restart ML service
docker compose restart ml-service
```

2. **Redis connection failed**
```bash
# Test Redis
docker compose exec redis redis-cli ping
# Should return: PONG
```

3. **ML service is optional**
```bash
# If ML fails, n8n still works with fallback routing
# Check n8n logs for "ML service unavailable" messages
```

---

### PostgreSQL Connection Issues

**Check**:
```bash
docker compose exec postgres psql -U n8n_user -d n8n_db -c "SELECT 1;"
```

**Solutions**:

1. **Password mismatch**
```bash
# Verify password in .env
grep POSTGRES_PASSWORD .env

# Recreate database with correct password
docker compose down -v
docker compose up -d postgres
```

2. **Database not initialized**
```bash
# Check if database exists
docker compose exec postgres psql -U n8n_user -l | grep n8n_db

# If missing, recreate:
docker compose down -v
docker compose up -d
```

---

### Redis Not Accessible

**Check**:
```bash
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" ping
```

**Solutions**:

1. **Authentication failed**
```bash
# Check password
grep REDIS_PASSWORD .env

# Test without auth (if requirepass not set)
docker compose exec redis redis-cli ping
```

2. **Redis down**
```bash
# Restart Redis
docker compose restart redis

# Check logs
docker compose logs redis
```

---

### Tor Proxy Not Working

**Check**:
```bash
# Test Tor proxy
curl --socks5-hostname tor:9050 https://check.torproject.org/api/ip
```

**Solutions**:

1. **Tor not started**
```bash
docker compose ps tor
docker compose logs tor

# Restart if needed
docker compose restart tor
```

2. **Control password mismatch**
```bash
# Verify password
grep TOR_CONTROL_PASSWORD .env

# Recreate with correct password
docker compose down tor
docker compose up -d tor
```

---

## 🟡 Workflow Issues

### Workflow Import Fails

**Symptoms**:
- "Invalid workflow JSON"
- Import script returns error

**Solutions**:

1. **Validate JSON**
```bash
# Check JSON syntax
jq . workflows/workflow-scraper-main.json

# Fix common issues:
# - Missing commas
# - Trailing commas
# - Unescaped quotes
```

2. **Check n8n version compatibility**
```bash
# Check n8n version
docker compose exec n8n n8n --version

# Workflow may require specific n8n version
# See workflow meta.compatibility field
```

3. **API authentication**
```bash
# Ensure N8N_API_KEY is set
echo $N8N_API_KEY

# Test API access
curl -H "X-N8N-API-KEY: $N8N_API_KEY" \
  http://localhost:5678/api/v1/workflows
```

---

### Workflow Executions Fail

**Check execution logs**:
```bash
# Via n8n UI
http://localhost:5678 → Executions tab

# Via API
curl -H "X-N8N-API-KEY: $N8N_API_KEY" \
  http://localhost:5678/api/v1/executions
```

**Common causes**:

1. **Missing credentials**
```json
// Check node credentials field
{
  "credentials": {
    "httpHeaderAuth": {
      "id": "1",
      "name": "API Key"  // Must exist in n8n
    }
  }
}
```

2. **Data access errors**
```javascript
// ❌ WRONG
const data = $input.item.body;  // undefined

// ✅ CORRECT
const data = $input.item.json.body || '';
```

3. **Network timeouts**
```json
{
  "parameters": {
    "options": {
      "timeout": 30000  // Increase if needed
    }
  }
}
```

---

## 🔵 Testing Issues

### CI/CD Tests Failing

**Symptoms**:
- GitHub Actions workflow fails
- "Webhook not ready" errors
- Timeout errors

**Solutions**:

1. **Wait for services**
```yaml
# Use health check polling, not fixed sleep
- name: Wait for n8n
  run: |
    for i in {1..90}; do
      curl -sf http://localhost:5678/healthz && exit 0
      sleep 1
    done
    exit 1
```

2. **Check secrets**
```yaml
# Ensure all secrets are set in GitHub
# Settings → Secrets and variables → Actions
POSTGRES_PASSWORD_CI
REDIS_PASSWORD_CI
N8N_USER_CI
N8N_PASSWORD_CI
N8N_API_KEY
```

3. **Webhook readiness**
```bash
# Use pre-flight check
bash scripts/test-n8n-workflows.sh
# Includes 10 retry attempts with 5s intervals
```

**Reference**: `docs/WEBHOOK_READINESS_FIX.md`

---

### Local Tests Pass, CI Fails

**Common differences**:

1. **Resource limits**
```yaml
# CI runners have limited resources
# Increase timeouts:
timeout-minutes: 15  # Instead of 5
```

2. **Timing issues**
```bash
# Services take longer to start in CI
# Add longer waits after docker compose up
sleep 12  # Minimum for PostgreSQL + n8n
```

3. **Network configuration**
```yaml
# Use service names, not localhost
N8N_URL: "http://n8n:5678"  # In docker network
N8N_URL: "http://localhost:5678"  # From host
```

---

## 🟢 Monitoring Issues

### Prometheus Not Scraping Metrics

**Check**:
```bash
# Prometheus targets
open http://localhost:9090/targets

# Should show all services as "UP"
```

**Solutions**:

1. **Service not exposing metrics**
```bash
# Check if endpoint responds
curl http://localhost:5678/metrics  # n8n
curl http://localhost:8000/metrics  # ml-service
```

2. **Prometheus config**
```bash
# Check config
docker compose exec prometheus cat /etc/prometheus/prometheus.yml

# Reload config
curl -X POST http://localhost:9090/-/reload
```

---

### Grafana Dashboard Empty

**Check**:
```bash
# Grafana datasource
open http://localhost:3000/datasources

# Should show Prometheus datasource
```

**Solutions**:

1. **Import dashboards**
```bash
# Dashboards in monitoring/grafana/dashboards/
# Import via Grafana UI or provisioning
```

2. **Datasource configuration**
```yaml
# monitoring/grafana/provisioning/datasources/datasource.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090  # Service name
```

---

## 📚 Quick Commands

### Diagnostic Commands

```bash
# Check all services
docker compose ps

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f n8n

# Restart service
docker compose restart n8n

# Full reset (WARNING: deletes data)
docker compose down -v
docker compose up -d

# Check n8n health
curl http://localhost:5678/healthz

# Test PostgreSQL
docker compose exec postgres pg_isready -U n8n_user

# Test Redis
docker compose exec redis redis-cli ping

# Check disk space
df -h
docker system df

# Clean Docker cache
docker system prune -a --volumes
```

---

## 🎯 When to Escalate

Escalate if:
- [ ] Data loss or corruption suspected
- [ ] Security vulnerability discovered
- [ ] Multiple services failing simultaneously
- [ ] Issue persists after full reset
- [ ] Performance severely degraded (>10x slower)

**Escalation checklist**:
1. Collect logs: `docker compose logs > debug.log`
2. Document steps to reproduce
3. Note environment details (OS, Docker version)
4. Create GitHub issue with logs + reproduction
5. Tag with appropriate labels (bug, critical, etc.)

---

## 🔗 References

- Main README: Quick start guide
- ARCHITECTURE.md: System design
- SECURITY.md: Security guidelines
- AUDIT-REPORT.md: Root cause analysis
- docs/CRITICAL_FIXES_2025-11-30.md: Authentication fixes
- docs/WEBHOOK_READINESS_FIX.md: CI/CD reliability

---

**Maintained by**: @KomarovAI  
**Last Updated**: 2025-11-30  
**Version**: 1.0
