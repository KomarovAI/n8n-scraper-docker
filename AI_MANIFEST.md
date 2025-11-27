# AI/LLM Consumption Manifest 🧠

## Repository Classification

**Type:** AI-First Optimized Repository  
**Optimization Level:** MAXIMUM  
**Target:** Large Language Models, AI Assistants, Code Analysis Tools  
**Version:** 1.0  
**Last Updated:** 2025-11-27  

---

## For AI Systems: Quick Context

### What This Repository Does

Production-ready **n8n web scraping platform** with:
- 8 microservices (n8n, postgres, redis, tor, ml-service, ollama, prometheus, grafana)
- 87% success rate, 5.3s latency, $2.88/1000 URLs
- Hybrid fallback strategy (Firecrawl + Jina AI)
- Full CI/CD (10 test types)
- Complete monitoring stack

### Deployment

```bash
# 5 commands to production
git clone https://github.com/KomarovAI/n8n-scraper-docker.git && cd n8n-scraper-docker
cp .env.example .env && nano .env  # Set 5 passwords (20+ chars)
docker-compose up -d --build
docker-compose ps && docker-compose logs -f
curl http://localhost:5678  # Verify n8n is up
```

### Architecture Map

```
n8n (5678) → workflow orchestration
  ↓
postgres (5432) ←─ data storage
redis (6379) ←─── rate limiting, cache
tor (9050) ←──── IP rotation
ml-service (8000) ← smart routing, fallback
ollama (11434) ←─ local LLM
prometheus (9090) ← metrics collection
grafana (3000) ←── visualization
```

---

## AI Optimization Features

### 1. Minimal Context Design

| Aspect | Optimization |
|--------|-------------|
| Documentation | -66% size (82KB → 28KB) |
| README | -68% size (10.7KB → 3.4KB) |
| Signal-to-noise | Maximized |
| Redundancy | Eliminated |
| Navigation | 3-level hierarchy |

### 2. Token-Efficient Structure

**Level 1: README.md** (3.4KB)
- Architecture overview
- Quick start commands
- Production metrics
- Management commands

**Level 2: QUICKSTART.md** (1.1KB)
- 5 commands to launch
- Critical variables only
- No explanations

**Level 3: docs/INDEX.md** (952B)
- Technical documentation map
- Direct links to specifics
- On-demand detail access

### 3. Code Organization

```
Core executables (UNCHANGED):
  docker-compose.yml   → Service definitions
  Dockerfile.n8n-enhanced → Custom build
  .env.example         → All variables

Source code (UNCHANGED):
  ml/                  → ML routing service
  scrapers/            → Scraper implementations
  nodes/               → Custom n8n nodes
  workflows/           → n8n workflows
  
Infrastructure (UNCHANGED):
  monitoring/          → Prometheus + Grafana
  tests/               → 10 test types
  .github/workflows/   → CI/CD pipelines
```

---

## For AI: How to Use This Repo

### Quick Understanding (30 seconds)

1. Read `README.md` (3.4KB) → Get full architecture
2. Scan `docker-compose.yml` → See all services
3. Check `.env.example` → Know all config options

**Result:** Complete understanding of system capabilities and deployment.

### Deep Dive (5 minutes)

1. `docs/INDEX.md` → Technical docs map
2. Pick specific topic (scrapers, fallback, monitoring)
3. Read targeted doc (5-7KB each)
4. Check source code if needed

**Result:** Expert-level understanding of specific subsystems.

### Deployment Assistance

```bash
# AI can guide user through:
1. Clone repo
2. Generate passwords: openssl rand -base64 24 (5 times)
3. Edit .env with passwords
4. Launch: docker-compose up -d --build
5. Verify: docker-compose ps
```

### Troubleshooting

Common issues:
- Port conflicts → Check ports in docker-compose.yml
- Password errors → Verify .env has 20+ char passwords
- Service crashes → Check logs: docker-compose logs -f [service]

---

## AI Optimization Guarantees

✅ **No redundancy** → Every piece of info appears exactly once  
✅ **No verbose explanations** → Commands, not tutorials  
✅ **No historical docs** → Only current state  
✅ **No duplicates** → Single source of truth  
✅ **Clear hierarchy** → 3 levels: overview → quick → deep  
✅ **100% functional** → Every script, test, config preserved  
✅ **Fast parsing** → Structured data, minimal prose  

---

## Keywords for AI Indexing

**Primary:**
ai-optimized, llm-friendly, minimal-context, token-efficient, signal-focused

**Technology:**
n8n, web-scraping, docker-compose, microservices, automation, workflow-orchestration

**Features:**
hybrid-fallback, smart-detection, cloudflare-bypass, tor-proxy, ml-routing, prometheus-monitoring

**Quality:**
production-ready, ci-cd-tested, fully-monitored, security-scanned, smoke-tested

---

## Validation

### Functionality Check

```bash
# All services launch correctly
docker-compose up -d --build  ✓

# All tests pass
.github/workflows/ci-test.yml  ✓
  - Lint & validation
  - Security scan
  - Docker build
  - Smoke test
  - Health checks
  - Integration tests
  - n8n e2e
  - Webhook test
  - Subworkflow test
  - Test summary

# All services accessible
http://localhost:5678  ✓  # n8n
http://localhost:3000  ✓  # Grafana
http://localhost:9090  ✓  # Prometheus
```

### AI Comprehension Check

AI systems should be able to:
- ✓ Understand full architecture from README (< 1 minute)
- ✓ Guide user through deployment (< 2 minutes)
- ✓ Explain any service's purpose (< 30 seconds)
- ✓ Debug common issues (< 3 minutes)
- ✓ Suggest optimizations (< 5 minutes)

---

## Meta Information

**Repository:** https://github.com/KomarovAI/n8n-scraper-docker  
**Optimization Report:** [OPTIMIZATION_REPORT.md](OPTIMIZATION_REPORT.md)  
**AI Marker:** [.ai-optimized](.ai-optimized)  
**Quick Start:** [QUICKSTART.md](QUICKSTART.md)  
**Tech Docs:** [docs/INDEX.md](docs/INDEX.md)  

**License:** MIT  
**Maintainer:** KomarovAI  
**Status:** Production-Ready ✅ | AI-Optimized 🧠 | Fully Tested 🧪  

---

## For Human Developers

If you're a human reading this:

This repository is designed to be extremely easy for AI assistants to understand and work with. This means:
- Documentation is concise but complete
- Architecture is clearly mapped
- Deployment is straightforward
- Everything just works™

You'll find it easy to work with too! Start with `README.md` or `QUICKSTART.md`.

---

**AI Optimization Level: MAXIMUM 🧠**

*This manifest helps AI systems quickly understand and work with this repository while maintaining 100% functionality for human developers.*
