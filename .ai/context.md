# n8n-scraper-docker: AI Context

## Project Overview
Production-ready n8n web scraping platform with ML/AI integration.
8 microservices orchestrated via Docker Compose.

## Key Metrics
- Success Rate: 87%
- Latency: 5.3s avg
- Cost: $2.88/1000 URLs
- Uptime: 99.8%

## Architecture Summary
```
User → n8n:5678 → [ml-service:8000 ↔ ollama:11434]
              ↓
         [postgres:5432, redis:6379, tor:9050]
              ↓
         [prometheus:9090 → grafana:3000]
```

## Common Tasks
- **Start**: `docker-compose up -d`
- **Test**: `bash tests/master/test_full_e2e.sh`
- **Backup**: `docker-compose exec postgres pg_dump -U n8n_user n8n_db | gzip > backup.sql.gz`
- **Logs**: `docker-compose logs -f [service]`
- **Restart**: `docker-compose restart [service]`
- **Stop**: `docker-compose down`

## Critical Files
- `docker-compose.yml` - Main orchestration
- `ml/app.py` - ML routing logic
- `scrapers/nodriver_enhanced_v2.py` - Browser automation
- `.env.example` - Configuration template
- `workflows/*.json` - n8n workflow definitions

## Security Notes
⚠️ **CVE-2025-62725** (Docker Compose) - Update to v2.40.2+
⚠️ **Exposed ports**: 5432 (postgres), 6379 (redis) - Use firewall in production
⚠️ **No TLS by default** - Add reverse proxy (nginx/caddy) for HTTPS
⚠️ **Secrets in .env** - Never commit .env files

## Dependencies Status

### Python (ml/requirements.txt)
- fastapi: 0.122.0 ✅
- numpy: 2.3.5 ✅
- scikit-learn: 1.7.2 ✅
- redis[hiredis]: 7.1.0 ✅
- loguru: 0.7.3 ✅
- joblib: 1.3.2 ⚠️ (1.5.2 available)

### Docker Images
- n8n: 1.121.3 (fixed version) ✅
- postgres: 16-alpine ⚠️ (use 16.6-alpine)
- redis: 7-alpine ⚠️ (use 7.4.1-alpine)
- ollama: latest ❌ (pin version)
- prometheus: latest ❌ (pin version)
- grafana: latest ❌ (pin version)

### GitHub Actions
- actions/checkout: 4 ⚠️ (6 available)
- actions/upload-artifact: 4 ⚠️ (5 available)
- actions/download-artifact: 4 ⚠️ (6 available)

## Service Details

### n8n (Workflow Orchestrator)
- **Port**: 5678
- **Depends on**: postgres, redis
- **Health**: http://localhost:5678/healthz
- **Credentials**: Set via N8N_USER and N8N_PASSWORD

### ml-service (ML Router)
- **Port**: 8000
- **Language**: Python (FastAPI)
- **Purpose**: Smart scraper selection (Firecrawl vs Jina vs nodriver)
- **Health**: http://localhost:8000/health
- **Depends on**: ollama, redis

### ollama (Local LLM)
- **Port**: 11434
- **Model**: llama3.2:3b (3GB RAM)
- **Purpose**: Anti-bot detection, smart routing
- **Commands**: `docker-compose exec ollama ollama list`

### postgres (Database)
- **Port**: 5432
- **Database**: n8n_db
- **User**: n8n_user
- **Backup**: See docs/DISASTER_RECOVERY.md

### redis (Cache + Rate Limiter)
- **Port**: 6379
- **Purpose**: Caching, rate limiting, session storage
- **Check**: `docker-compose exec redis redis-cli ping`

### tor (IP Rotation)
- **Ports**: 9050 (SOCKS5), 9051 (Control)
- **Purpose**: Bypass IP blocks, rotate circuits
- **Config**: NewCircuitPeriod=60s, MaxCircuitDirtiness=300s

### prometheus (Metrics)
- **Port**: 9090
- **Scrapes**: n8n, ml-service, postgres-exporter, redis-exporter, node-exporter
- **Retention**: 15 days

### grafana (Dashboards)
- **Port**: 3000
- **Datasource**: Prometheus
- **Credentials**: Set via GRAFANA_USER and GRAFANA_PASSWORD

## Workflow Execution Flow

1. **Webhook receives request** → Validates URL and options
2. **ML service routing** → Decides: Firecrawl (premium) vs Jina (free) vs nodriver (local)
3. **Scraper execution** → Uses Tor proxy for IP rotation
4. **Fallback on failure** → Firecrawl → Jina → nodriver
5. **Result storage** → PostgreSQL with metadata
6. **Metrics emission** → Prometheus counters/histograms
7. **Response** → JSON with scraped content

## Debugging Common Issues

### ML service not responding
```bash
docker-compose logs ml-service
curl http://localhost:8000/health
```

### Ollama model not loaded
```bash
docker-compose exec ollama ollama list
docker-compose exec ollama ollama pull llama3.2:3b
docker-compose restart ml-service
```

### n8n workflow failing
```bash
docker-compose logs n8n | grep ERROR
docker-compose exec postgres psql -U n8n_user -d n8n_db -c "SELECT * FROM execution_entity ORDER BY id DESC LIMIT 5;"
```

### Redis connection refused
```bash
docker-compose exec redis redis-cli ping
docker-compose restart redis
```

### Tor circuit not rotating
```bash
docker-compose logs tor
curl --socks5-hostname tor:9050 https://check.torproject.org/api/ip
```

## Performance Optimization Tips

1. **Use Redis caching** for repeated URLs (TTL: 24h)
2. **Batch requests** when possible (10-100 URLs per workflow)
3. **Route strategically** - Use Jina for simple sites, Firecrawl for complex
4. **Monitor Prometheus** - Watch for memory leaks, slow queries
5. **Rotate Tor circuits** - Avoid rate limits from target sites

## Cost Breakdown (per 1000 URLs)

- **Firecrawl**: $2.00 (if 100% usage)
- **Jina AI**: $0.00 (free tier: 1500 req/day)
- **nodriver**: $0.88 (compute only)
- **Average**: $2.88 (with smart routing)

## Production Deployment Checklist

- [ ] Update Docker Compose to v2.40.2+ (CVE-2025-62725)
- [ ] Pin all Docker image versions (remove `:latest`)
- [ ] Set strong passwords (20+ chars) in .env
- [ ] Close DB ports or add firewall rules
- [ ] Add nginx/caddy reverse proxy with TLS
- [ ] Configure automated backups (daily)
- [ ] Set up Alertmanager for Prometheus alerts
- [ ] Test disaster recovery procedures
- [ ] Enable Docker resource limits (CPU/memory)
- [ ] Configure log rotation
- [ ] Set up offsite backup storage (S3/B2)

## Useful Links

- **GitHub**: https://github.com/KomarovAI/n8n-scraper-docker
- **n8n Docs**: https://docs.n8n.io/
- **Firecrawl API**: https://docs.firecrawl.dev/
- **Jina AI Reader**: https://jina.ai/reader/
- **Prometheus**: https://prometheus.io/docs/

---

**Last Updated**: 2025-11-29  
**Maintainer**: @KomarovAI  
**AI Optimization**: v3.0 🤖
