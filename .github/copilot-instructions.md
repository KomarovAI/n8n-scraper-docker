# GitHub Copilot Instructions

## Repository Context

**Type:** Production-ready n8n web scraping platform  
**Stack:** n8n, Docker Compose, PostgreSQL, Redis, Tor, ML service, Ollama, Prometheus, Grafana  
**Architecture:** 8 microservices orchestrated via Docker Compose  
**Status:** AI-optimized (minimal context, token-efficient)  

### Performance Metrics
- Success rate: 87%
- Avg latency: 5.3s
- Cost: $2.88/1000 URLs
- Cloudflare bypass: 90-95%

### Key Features
- Hybrid fallback strategy (Firecrawl + Jina AI)
- Smart anti-detection routing
- Full CI/CD (10 test types)
- Complete monitoring stack

---

## Coding Standards

### Documentation Style
- **Signal-based comments** (no tutorials, no verbose explanations)
- **Token-efficient** (one-liners preferred for obvious code)
- **Self-documenting code** (clear function/variable names)
- **Context markers** for large files:
  ```python
  """
  CONTEXT: [Brief description]
  DEPENDENCIES: [Key deps]
  TOKEN_PRIORITY: high|medium|low
  """
  ```

### Code Patterns
- ES6+ JavaScript (const/let, arrow functions, async/await)
- Python 3.9+ (type hints, async where beneficial)
- Docker best practices (multi-stage builds, layer optimization)
- RESTful APIs (standard HTTP methods, clear endpoints)

### Naming Conventions
- Functions: `verbNoun` (e.g., `fetchData`, `parseResponse`)
- Classes: `PascalCase` (e.g., `ScraperRouter`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_RETRIES`)
- Files: `kebab-case` (e.g., `scraper-router.js`)

### Error Handling
- Use try/catch for async operations
- Return meaningful error messages
- Log errors with context (service name, operation, timestamp)
- Fail gracefully (fallback strategies)

---

## AI Optimization Rules

### Documentation
- ❌ **DON'T** add verbose explanations to README
- ❌ **DON'T** create new markdown files without updating docs/INDEX.md
- ❌ **DON'T** duplicate information across files
- ✅ **DO** keep README architectural and command-focused
- ✅ **DO** use QUICKSTART.md for setup steps
- ✅ **DO** add technical details to docs/ with INDEX update
- ✅ **DO** maintain single source of truth

### Code Changes
- Keep all changes **minimal** (surgical edits only)
- Follow existing patterns (consistency > innovation)
- Preserve existing comments unless outdated
- No TODO comments (create GitHub issues instead)

### Testing
- All new features require tests
- Follow existing test patterns (smoke, e2e, integration)
- Tests must pass before commit
- Use descriptive test names

---

## Architecture Guidelines

### Service Communication
```
n8n (5678) → orchestration layer
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

### Critical Paths
1. **Workflow execution**: n8n → ml-service → scrapers → storage
2. **Data persistence**: n8n → postgres (all workflow data)
3. **Rate limiting**: n8n → redis (request throttling)
4. **Monitoring**: All services → prometheus → grafana

### Dependencies
- **ml-service** depends on: ollama, redis
- **n8n** depends on: postgres, redis, tor, ml-service
- **grafana** depends on: prometheus
- **prometheus** depends on: all services (metrics endpoints)

---

## Common Tasks

### Adding a New Scraper
1. Create file in `scrapers/[name]-scraper.py`
2. Implement base interface (fetch, parse, validate)
3. Add tests in `tests/integration/test-[name]-scraper.py`
4. Update ML routing in `ml/router.py`
5. Add fallback logic if applicable

### Modifying Workflows
1. Export workflow from n8n UI (JSON)
2. Save to `workflows/[name].json`
3. Add test in `tests/e2e/workflow-[name].test.js`
4. Update `workflows/README.md` if new workflow

### Adding Monitoring
1. Add metrics endpoint to service
2. Update `monitoring/prometheus.yml` (scrape config)
3. Create dashboard in `monitoring/grafana/dashboards/`
4. Document in `docs/INDEX.md`

### Environment Variables
1. Add to `.env.example` with description
2. Document in README.md if critical
3. Update docker-compose.yml service config
4. Validate in CI/CD pipeline

---

## Testing Strategy

### Test Types (all must pass)
1. **Lint & validation** - Code quality
2. **Security scan** - Trivy + TruffleHog
3. **Docker build** - Image creation
4. **Smoke test** - Container stability
5. **Health checks** - Service availability
6. **Integration tests** - Service communication
7. **n8n e2e** - Workflow execution
8. **Webhook tests** - Entry point validation
9. **Subworkflow tests** - Workflow composition
10. **Test summary** - Results aggregation

### Running Tests Locally
```bash
# All tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Specific test
docker-compose run test-[name]

# Manual verification
docker-compose up -d && docker-compose ps
```

---

## Security Guidelines

### Secrets Management
- Never commit `.env` (in .gitignore)
- Use 20+ char passwords (generate with `openssl rand -base64 24`)
- Rotate passwords every 90 days
- Use environment variables (never hardcode)

### API Keys
- Store in `.env` (FIRECRAWL_API_KEY, JINA_API_KEY)
- Validate presence at startup
- Log errors without exposing keys
- Use separate keys for dev/prod

### Container Security
- Run as non-root user where possible
- Use official base images
- Pin image versions (no :latest)
- Scan with Trivy in CI/CD

---

## Performance Optimization

### Docker Compose
- Use `depends_on` for startup order
- Health checks for service readiness
- Resource limits (memory, CPU)
- Volume mounts for persistence

### PostgreSQL
- Connection pooling (max 20 connections)
- Indexes on frequently queried fields
- Regular VACUUM operations
- Backup strategy (pg_dump daily)

### Redis
- Memory limit (maxmemory-policy: allkeys-lru)
- Persistence (RDB + AOF)
- Connection timeout (10s)
- Key expiration for cache

### ML Service
- Model caching (Ollama pulls)
- Request batching where possible
- Async processing (non-blocking)
- Circuit breaker for fallbacks

---

## Deployment Checklist

- [ ] All tests pass locally
- [ ] `.env` configured with strong passwords
- [ ] Docker images build successfully
- [ ] Services start in correct order
- [ ] Health checks passing
- [ ] Monitoring dashboards accessible
- [ ] Logs show no errors
- [ ] Workflows import successfully
- [ ] Test workflow executes
- [ ] Metrics being collected

---

## AI-Specific Notes

### This Repository is AI-Optimized
- Documentation reduced by 48%
- Token-efficient structure
- Signal-focused content
- Clear 3-level navigation
- Single source of truth
- No redundancy

### When Generating Code
- Prefer minimal, focused functions
- Use existing patterns from codebase
- Add comments only for complex logic
- Follow architecture guidelines above
- Test thoroughly before committing

### When Reviewing Code
- Check for consistency with existing patterns
- Verify tests are included
- Ensure documentation is updated (if needed)
- Validate no secrets are exposed
- Confirm AI optimization maintained

---

## Quick Reference

**Start system:** `docker-compose up -d --build`  
**Stop system:** `docker-compose down`  
**View logs:** `docker-compose logs -f [service]`  
**Run tests:** `.github/workflows/ci-test.yml`  
**Access n8n:** http://localhost:5678  
**Access Grafana:** http://localhost:3000  

**Documentation:**  
- Architecture: `README.md`
- Quick start: `QUICKSTART.md`
- AI guide: `AI_MANIFEST.md`
- Technical docs: `docs/INDEX.md`
- Optimization: `OPTIMIZATION_REPORT.md`

---

**Status:** Production-Ready ✅ | AI-Optimized 🧠 | Fully Tested 🧪
