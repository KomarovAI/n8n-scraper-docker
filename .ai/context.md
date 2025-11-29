# n8n-scraper-docker: AI Context

## Overview
Production ML-powered web scraping platform. 8 Docker microservices.

**Metrics**: 87% success | 5.3s latency | $2.88/1K URLs | 99.8% uptime

## Architecture
```
User → n8n:5678 → [ml-service:8000 ↔ ollama:11434]
               ↓
          [postgres:5432, redis:6379, tor:9050]
               ↓
          [prometheus:9090 → grafana:3000]
```

## Quick Commands
```bash
docker-compose up -d                           # Start
bash tests/master/test_full_e2e.sh             # Test E2E
docker-compose logs -f [service]               # Logs
docker-compose exec postgres pg_dump ... | gzip # Backup
```

## Critical Files
- `docker-compose.yml` - Orchestration
- `ml/app.py` - ML routing
- `scrapers/*.py` - Implementations
- `.env.example` - Config template

## Security ⚠️
**CVE-2025-62725**: Docker Compose < v2.40.2 vulnerable  
**Production**: Close 5432,6379 | Add TLS proxy | Never commit .env

## Service Matrix

| Service | Port | Purpose | Health Check |
|---------|------|---------|-------------|
| n8n | 5678 | Orchestrator | /healthz |
| ml-service | 8000 | Smart routing | /health |
| ollama | 11434 | LLM (llama3.2:3b) | /api/tags |
| postgres | 5432 | Storage | pg_isready |
| redis | 6379 | Cache | redis-cli ping |
| tor | 9050 | IP rotation | - |
| prometheus | 9090 | Metrics | /-/healthy |
| grafana | 3000 | Dashboards | /api/health |

## Workflow Flow
1. Webhook → Validate
2. ML → Route (Firecrawl/Jina/nodriver)
3. Scrape via Tor proxy
4. Fallback on fail
5. Store → PostgreSQL
6. Emit → Prometheus
7. Return JSON

## Debug Common Issues

**ML not responding**
```bash
docker-compose logs ml-service
curl http://localhost:8000/health
```

**Ollama model missing**
```bash
docker-compose exec ollama ollama pull llama3.2:3b
docker-compose restart ml-service
```

**n8n workflow fails**
```bash
docker-compose logs n8n | grep ERROR
```

**Redis down**
```bash
docker-compose exec redis redis-cli ping
```

## Cost Breakdown (per 1K URLs)
- Firecrawl: $2.00 (if 100%)
- Jina AI: $0.00 (free tier)
- nodriver: $0.88 (compute)
- **Average: $2.88** (smart routing)

## Production Checklist
- [ ] Docker Compose v2.40.2+
- [ ] Pin all :latest images
- [ ] 20+ char passwords
- [ ] Firewall DB ports
- [ ] Add nginx/caddy TLS
- [ ] Daily backups
- [ ] Prometheus alerts
- [ ] Resource limits

## Links
- GitHub: https://github.com/KomarovAI/n8n-scraper-docker
- Docs: `.ai/instructions.md`, `ARCHITECTURE.md`, `SECURITY.md`

**Updated**: 2025-11-29 | **Maintainer**: @KomarovAI | **v3.0** 🤖
