# Contributing Guide for AI Agents

## Before Making Changes

1. **Read** `.ai/context.md` for project overview
2. **Check** `.ai/instructions.md` for code patterns
3. **Review** `ARCHITECTURE.md` for design decisions
4. **Validate** `docker-compose.yml` syntax: `docker-compose config`

## Proposing Changes

### PR Template for AI-Generated Changes

```markdown
## Change Summary
[1-2 sentences describing what was changed and why]

## Files Modified
- `file1.py`: Added X function for Y purpose
- `docker-compose.yml`: Updated Z service configuration
- `ml/requirements.txt`: Bumped dependency A to version B

## Testing Done
- [ ] Unit tests pass: `pytest tests/unit/`
- [ ] Integration tests pass: `pytest tests/integration/`
- [ ] E2E tests pass: `bash tests/master/test_full_e2e.sh`
- [ ] Manual testing: [describe what was tested]
- [ ] Docker Compose validation: `docker-compose config`

## Breaking Changes
None / [describe breaking changes and migration path]

## Rollback Plan
[If production change, describe how to rollback]

## Related Issues
Fixes #[issue_number] / Part of #[epic_number]
```

## Code Review Checklist

### Security
- [ ] No hardcoded secrets (passwords, API keys, tokens)
- [ ] All secrets use environment variables
- [ ] Sensitive values have `# @ai-ignore` comments
- [ ] No `.env` files committed
- [ ] External API calls have timeout limits

### Code Quality
- [ ] All new functions have docstrings
- [ ] Type hints present (Python)
- [ ] JSDoc comments for complex functions (JavaScript)
- [ ] Error handling for all external APIs
- [ ] Logging added for critical paths
- [ ] No TODOs or placeholder code

### Testing
- [ ] Unit tests added for new functions
- [ ] Integration tests cover happy path + error cases
- [ ] E2E tests pass on local environment
- [ ] Test coverage ≥80% for new code

### Documentation
- [ ] README.md updated (if user-facing change)
- [ ] ARCHITECTURE.md updated (if architectural change)
- [ ] API.md updated (if API change)
- [ ] CHANGELOG.md entry added
- [ ] Inline comments for complex logic

### Docker/Infrastructure
- [ ] Resource limits set for new services (CPU/memory)
- [ ] Healthchecks defined for new services
- [ ] Volumes configured for data persistence
- [ ] Networks properly configured
- [ ] No `:latest` tags in production images

### Performance
- [ ] No synchronous blocking operations in async code
- [ ] Database queries optimized (indexes, LIMIT clauses)
- [ ] Redis caching used where appropriate
- [ ] Rate limiting implemented for external APIs

## Common Patterns

### Adding a New Scraper

```python
# 1. Create scrapers/new_scraper.py
from .base import ScraperBase

class NewScraper(ScraperBase):
    def scrape(self, url: str) -> str:
        try:
            # Implementation
            return html_content
        except Exception as e:
            self.logger.error(f"Scrape failed: {url}", exc_info=e)
            raise

# 2. Register in ml/app.py
from scrapers.new_scraper import NewScraper

# Add to routing logic
if score > 0.9:
    return "new_scraper"

# 3. Add tests
# tests/scrapers/test_new_scraper.py
```

### Modifying ML Routing

```python
# ml/app.py
@app.post("/route")
async def route_scraping_request(request: RouteRequest):
    try:
        # 1. Extract features from URL
        features = extract_features(request.url)
        
        # 2. Get prediction from model
        score = ml_model.predict(features)
        
        # 3. Route based on score
        if score > 0.7:
            scraper = "firecrawl"
        elif score > 0.4:
            scraper = "jina"
        else:
            scraper = "nodriver"
        
        # 4. Log decision
        logger.info(f"Routed {request.url} to {scraper} (score: {score:.2f})")
        
        return {"scraper": scraper, "confidence": score}
    except Exception as e:
        logger.error("Routing failed", exc_info=e)
        return {"scraper": "jina", "confidence": 0.0}  # Fallback
```

### Adding Environment Variables

```bash
# 1. Add to .env.example
NEW_API_KEY=your_api_key_here  # @ai-ignore

# 2. Add to docker-compose.yml
services:
  ml-service:
    environment:
      - NEW_API_KEY=${NEW_API_KEY}  # @ai-ignore

# 3. Use in code
import os
NEW_API_KEY = os.getenv("NEW_API_KEY")  # @ai-ignore
if not NEW_API_KEY:
    raise ValueError("NEW_API_KEY not set")

# 4. Document in README.md
```

### Adding a New Service

```yaml
# docker-compose.yml
services:
  new-service:
    image: your/image:1.0.0  # Pin version, no :latest
    container_name: new-service
    restart: unless-stopped
    environment:
      - SERVICE_CONFIG=${SERVICE_CONFIG}
    ports:
      - "8080:8080"  # Only expose if necessary
    volumes:
      - new-service-data:/data
    networks:
      - n8n-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

volumes:
  new-service-data:

networks:
  n8n-network:
    driver: bridge
```

## Debugging Common Issues

### Service won't start
```bash
# Check logs
docker-compose logs [service]

# Validate compose file
docker-compose config

# Check service health
docker-compose ps
```

### Database connection failed
```bash
# Check postgres is running
docker-compose ps postgres

# Test connection
docker-compose exec postgres psql -U n8n_user -d n8n_db -c "SELECT 1;"

# Check credentials
cat .env | grep POSTGRES
```

### ML service routing errors
```bash
# Check ml-service logs
docker-compose logs ml-service

# Test health endpoint
curl http://localhost:8000/health

# Check ollama connection
docker-compose exec ollama ollama list
```

### Tests failing in CI
```bash
# Run tests locally
bash tests/master/test_full_e2e.sh

# Check for environment differences
diff .env.example .env

# Rebuild containers
docker-compose down -v && docker-compose up -d --build
```

## Git Commit Conventions

```bash
# Format: <type>(<scope>): <subject>

# Types:
feat:     # New feature
fix:      # Bug fix
refactor: # Code refactoring
docs:     # Documentation
test:     # Tests
chore:    # Maintenance
perf:     # Performance improvement
style:    # Code style (formatting)

# Examples:
feat(ml): add new scraper selection algorithm
fix(docker): resolve redis connection timeout
refactor(scrapers): optimize nodriver memory usage
docs(api): update ML service endpoint documentation
test(integration): add fallback scenario tests
chore(deps): bump numpy from 1.26.2 to 2.3.5
perf(redis): implement connection pooling
style(python): format code with black
```

## Code Style Enforcement

### Python
```bash
# Format code
black .

# Check style
flake8 .

# Type checking
mypy ml/ scrapers/
```

### JavaScript/TypeScript
```bash
# Format code
prettier --write .

# Check style
eslint .
```

### YAML
```bash
# Validate docker-compose
docker-compose config

# Validate GitHub workflows
actionlint .github/workflows/*.yml
```

## Testing Requirements

### Unit Tests (Required)
- Test individual functions in isolation
- Mock external dependencies (APIs, databases)
- Coverage ≥80% for new code

### Integration Tests (Required)
- Test service interactions
- Use test containers for postgres/redis
- Cover happy path + error scenarios

### E2E Tests (Required for major changes)
- Test complete workflows
- Use production-like environment
- Verify metrics and logging

## Performance Guidelines

### Benchmarks to Meet
- Response time: <5.3s (average)
- Success rate: ≥87%
- Memory usage: Stable over 24h
- No memory leaks

### Profiling
```bash
# Python profiling
python -m cProfile -o profile.stats ml/app.py
snakeviz profile.stats

# Docker stats
docker stats --no-stream

# Prometheus metrics
open http://localhost:9090
```

## Security Scanning

### Before Committing
```bash
# Scan for secrets
git secrets --scan

# Check dependencies
pip-audit
npm audit

# Docker image scanning
docker scan n8n-scraper:latest
```

## Getting Help

- **Documentation**: Check `.ai/context.md` and `ARCHITECTURE.md`
- **Issues**: Search existing issues on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Maintainer**: @KomarovAI

---

**Last Updated**: 2025-11-29  
**For AI Agents**: Follow these guidelines to ensure high-quality contributions
