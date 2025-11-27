# GitHub Copilot Instructions - n8n-scraper-docker

**📢 This file references unified AI instructions**

## Primary Instructions Location

👉 **Read**: [.ai/instructions.md](../.ai/instructions.md)

All AI assistants (GitHub Copilot, Cursor, Windsurf, ChatGPT, Claude) use the same instructions for consistency.

## Quick Context

**Type**: Production n8n scraping platform (8 microservices)  
**Status**: AI-optimized v2.0 (minimal context, token-efficient)  
**Metrics**: 87% success, 5.3s latency, $2.88/1000 URLs  

## Core Principles (Summary)

1. **Token efficiency** - Minimal comments, compact code
2. **Production-ready** - No TODOs, complete error handling
3. **Security first** - Never hardcode secrets, use `@ai-ignore`
4. **Architecture alignment** - Follow microservices pattern (8 services)

## Architecture Overview

```
n8n (5678) → workflow orchestration
  ↓
postgres (5432) ← data persistence
redis (6379) ← rate limiting, cache
tor (9050) ← IP rotation
ml-service (8000) ← routing decisions
  ↓
ollama (11434) ← local LLM
  
prometheus (9090) → metrics collection
grafana (3000) → visualization
```

## Quick Commands

```bash
# Start platform
docker-compose up -d --build

# View logs
docker-compose logs -f n8n

# Run tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Access services
open http://localhost:5678  # n8n
open http://localhost:3000  # Grafana
open http://localhost:9090  # Prometheus
```

## Navigation Priority

**Read these first when generating code:**

### Critical (always read)
1. `README.md` - Overview, quick start, metrics
2. `docker-compose.yml` - Service definitions, networking
3. `.env.example` - Required environment variables
4. `.aimeta.json` - Project metadata, architecture

### High Priority
5. `ARCHITECTURE.md` - Detailed architecture, mermaid diagrams
6. `workflows/` - n8n workflow JSON files
7. `scrapers/` - Scraper implementations
8. `ml/` - ML service for smart routing

### Medium Priority
9. `monitoring/` - Prometheus, Grafana configs
10. `tests/` - Test suites
11. `docs/HYBRID_FALLBACK_STRATEGY.md` - Fallback logic
12. `docs/NODRIVER_ENHANCED_V2.md` - nodriver scraper details

### Low Priority (only if specifically asked)
13. `.github/workflows/` - CI/CD pipelines
14. `scripts/` - Utility scripts

## Common Tasks

### Adding a New Scraper
1. Create `scrapers/[name]-scraper.py` with base interface
2. Implement fetch, parse, validate methods
3. Add tests in `tests/integration/test-[name]-scraper.py`
4. Update ML routing in `ml/router.py`
5. Add fallback logic if applicable

### Modifying Workflows
1. Export workflow from n8n UI (JSON)
2. Save to `workflows/[name].json`
3. Add test in `tests/e2e/workflow-[name].test.js`
4. Update documentation if new workflow

### Adding Environment Variables
1. Add to `.env.example` with description
2. Document in README.md if critical
3. Update `docker-compose.yml` service config
4. Validate in CI/CD pipeline

## Testing Strategy

**All 10 test types must pass:**
1. Lint & validation
2. Security scan (Trivy + TruffleHog)
3. Docker build
4. Smoke test (container stability)
5. Health checks
6. Integration tests
7. n8n workflow e2e
8. Webhook validation
9. Subworkflow tests
10. Test summary

## Security Guidelines

- Never commit `.env` (in .gitignore)
- Use 20+ char passwords (`openssl rand -base64 24`)
- Store API keys in `.env` with `# @ai-ignore` comment
- Rotate passwords every 90 days
- Validate secrets at startup

## Full Guidelines

📖 **Complete instructions**: [.ai/instructions.md](../.ai/instructions.md)

Includes:
- Detailed code style guidelines (JavaScript, Python, Docker)
- Common pitfalls to avoid (rate limits, hardcoded keys, missing fallback)
- Testing patterns (Jest, pytest)
- Workflow architecture (n8n patterns)
- Performance targets (87% success, 5.3s latency)
- Environment variables reference

---

**AI-Optimized v2.0 🧠** | Production-Ready ✅ | Auto-Tested 🧪 | Token-Efficient 🚀
