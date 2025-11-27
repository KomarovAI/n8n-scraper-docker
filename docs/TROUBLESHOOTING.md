# Troubleshooting Guide

> **Quick Fix:** If workflows are not starting, run the automated setup script:
> ```bash
> chmod +x scripts/setup.sh
> ./scripts/setup.sh
> ```

## Common Issues and Solutions

### Issue 1: "POSTGRES_PASSWORD must be set in .env file"

**Cause:** Missing or incomplete `.env` file.

**Solution:**
```bash
# 1. Create .env from example
cp .env.example .env

# 2. Generate secure passwords
for i in {1..5}; do openssl rand -base64 24; done

# 3. Edit .env and replace ALL CHANGE_ME_* values
nano .env

# Required variables:
# - POSTGRES_PASSWORD
# - REDIS_PASSWORD
# - N8N_PASSWORD
# - TOR_CONTROL_PASSWORD
# - GRAFANA_PASSWORD
```

---

### Issue 2: ML Service Failing with "Model not found"

**Cause:** Ollama model not downloaded.

**Symptoms:**
```
ml-service    | ERROR: Ollama API error: 404
ml-service    | Model "llama3:8b" not found
```

**Solution:**
```bash
# 1. Check if model exists
docker-compose exec ollama ollama list

# 2. Download model (choose ONE):

# Option A: Small model (1.5 GB, fast)
docker-compose exec ollama ollama pull phi3:mini

# Option B: Medium model (3 GB, balanced) - RECOMMENDED
docker-compose exec ollama ollama pull llama3.2:3b

# Option C: Large model (4.7 GB, accurate)
docker-compose exec ollama ollama pull llama3:8b

# 3. Restart ML service
docker-compose restart ml-service

# 4. Verify health
curl http://localhost:8000/health
```

---

### Issue 3: Workflow Not Responding to Triggers

**Cause:** Workflows not imported or not activated in n8n.

**Symptoms:**
```
Test 8: Testing n8n webhook endpoint
⚠️ WARNING: Webhook timed out or failed
```

**Solution:**

**Manual Import (Recommended):**
1. Open http://localhost:5678
2. Login with credentials from `.credentials.txt` or `.env`
3. Click n8n logo (top-left) → **Workflows** → **Import from File**
4. Import each file from `workflows/` folder:
   - `workflow-scraper-main.json`
   - `workflow-scraper-enhanced.json`
   - `control-panel.json`
5. **Activate each workflow** (toggle "Inactive" → "Active")

**Automated Import (via API):**
```bash
#!/bin/bash
N8N_URL="http://localhost:5678"
N8N_USER="admin"  # From .env
N8N_PASSWORD="your_password"  # From .env

# Get auth token
COOKIE=$(curl -s -c - "${N8N_URL}/rest/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${N8N_USER}\",\"password\":\"${N8N_PASSWORD}\"}" \
  | grep "n8n-auth" | awk '{print $7}')

# Import workflows
for workflow in workflows/*.json; do
  echo "Importing $workflow..."
  curl -X POST "${N8N_URL}/rest/workflows" \
    -H "Cookie: n8n-auth=${COOKIE}" \
    -H "Content-Type: application/json" \
    -d @"$workflow"
done
```

---

### Issue 4: Services Stuck in "starting" State

**Cause:** Healthcheck timeouts too aggressive for slow systems.

**Symptoms:**
```bash
$ docker-compose ps
NAME              STATUS
n8n-ml-service    Up (unhealthy)
n8n-ollama        Up (starting)
n8n-app           Up (health: starting)
```

**Solution:**

Healthcheck timeouts have been increased in `docker-compose.yml`:
- `ollama`: 60s → **180s** (allows model downloads)
- `ml-service`: 40s → **120s** (classifier training)
- `n8n`: 40s → **90s** (DB migrations)

**If still timing out:**
```bash
# 1. Check logs for actual errors
docker-compose logs ml-service
docker-compose logs ollama
docker-compose logs n8n

# 2. Wait longer (first start can take 3-5 minutes)
sleep 180

# 3. Check again
docker-compose ps
```

---

### Issue 5: n8n Taking Long Time to Start

**Cause:** PostgreSQL database migrations running (first start only).

**Expected Behavior:**
```
n8n           | Initializing n8n process
n8n           | Database migrations starting...
n8n           | Running migration 1/52: AddWorkflowSettings
...           | (60-120 seconds)
n8n           | Running migration 52/52: AddExecutionDataSize
n8n           | Database migrations completed
n8n           | n8n ready on port 5678
```

**Solution:**
```bash
# Monitor migration progress
docker-compose logs -f n8n | grep -E "(migration|ready)"

# Wait for completion message
# First start: 60-120 seconds
# Subsequent starts: 5-10 seconds

# Verify readiness
curl http://localhost:5678/healthz
# Expected: {"status":"ok"}
```

---

## Diagnostic Commands

### Check Service Status
```bash
# All services
docker-compose ps

# Expected output:
NAME                STATUS
n8n-postgres        Up (healthy)
n8n-redis           Up (healthy)
n8n-tor             Up (healthy)
n8n-ollama          Up (healthy)
n8n-ml-service      Up (healthy)
n8n-prometheus      Up (healthy)
n8n-grafana         Up
n8n-app             Up (healthy)
```

### Check Service Logs
```bash
# All services (last 50 lines)
docker-compose logs --tail=50

# Specific service
docker-compose logs -f n8n
docker-compose logs -f ml-service
docker-compose logs -f ollama

# Grep for errors
docker-compose logs | grep -i error
```

### Test Service Endpoints
```bash
# n8n
curl -I http://localhost:5678/healthz

# ML service
curl http://localhost:8000/health

# Ollama
curl http://localhost:11434/api/tags

# Prometheus
curl http://localhost:9090/-/healthy

# PostgreSQL
docker-compose exec postgres pg_isready -U scraper_user

# Redis
docker-compose exec redis redis-cli ping
```

### Check Ollama Models
```bash
# List installed models
docker-compose exec ollama ollama list

# Expected output:
NAME              ID              SIZE      MODIFIED
llama3.2:3b      a80c4f17acd5    2.0 GB    5 minutes ago

# If empty, download model:
docker-compose exec ollama ollama pull llama3.2:3b
```

### Check PostgreSQL Database
```bash
# Connect to database
docker-compose exec postgres psql -U scraper_user -d scraper_db

# List tables
\dt

# Check workflow executions
SELECT COUNT(*) FROM execution_entity;

# Exit
\q
```

### Check Resource Usage
```bash
# Container stats
docker stats --no-stream

# Disk usage
docker system df

# Volume sizes
docker volume ls
docker volume inspect n8n-scraper-docker_postgres-data
```

---

## Complete Reset Procedure

If all else fails, perform a complete reset:

```bash
# 1. Stop all services
docker-compose down

# 2. Remove all volumes (⚠️ DELETES ALL DATA)
docker-compose down -v

# 3. Remove all images
docker-compose down --rmi all

# 4. Clean Docker system
docker system prune -af

# 5. Remove local data directories (if they exist)
rm -rf postgres-data redis-data n8n-data ollama-data

# 6. Start fresh with setup script
chmod +x scripts/setup.sh
./scripts/setup.sh
```

---

## Performance Optimization

### Slow Startup on Low-Spec Systems

If running on a system with:
- < 4 GB RAM
- < 2 CPU cores
- Slow disk I/O

**Optimizations:**

1. **Use smaller Ollama model:**
```bash
docker-compose exec ollama ollama pull phi3:mini  # 1.5 GB vs 3 GB
```

2. **Disable ML service (optional):**
```yaml
# docker-compose.yml
# Comment out ml-service and dependencies
```

3. **Reduce concurrent workers:**
```yaml
# ml/Dockerfile
CMD ["uvicorn", "scraping_strategy_selector:app", "--workers", "1"]  # Was 2
```

---

## Getting Help

### Before Opening an Issue

1. **Run Master E2E Test:**
```bash
chmod +x tests/master/test_full_e2e.sh
bash tests/master/test_full_e2e.sh
```

2. **Collect diagnostic info:**
```bash
# System info
uname -a
docker --version
docker-compose --version

# Service status
docker-compose ps > diagnostic.txt

# Logs (last 100 lines per service)
docker-compose logs --tail=100 >> diagnostic.txt

# Resource usage
docker stats --no-stream >> diagnostic.txt
```

3. **Check existing issues:**
   - [GitHub Issues](https://github.com/KomarovAI/n8n-scraper-docker/issues)

### Reporting Issues

Include:
- Output of diagnostic commands above
- Steps to reproduce
- Expected vs actual behavior
- Environment (OS, Docker version, RAM, CPU)

---

## Quick Reference

| Problem | Quick Fix |
|---------|----------|
| Missing .env | `cp .env.example .env` + edit passwords |
| Ollama model missing | `docker-compose exec ollama ollama pull llama3.2:3b` |
| Workflows not working | Import via UI + activate |
| Services unhealthy | Wait 3-5 minutes, check logs |
| n8n slow start | DB migrations (60-120s first time) |
| Complete reset | `docker-compose down -v && ./scripts/setup.sh` |

---

**Last Updated:** 2025-11-27
