# AI Assistant Instructions - n8n-scraper-docker

**Version**: 2.0  
**Compatible with**: GitHub Copilot, Cursor, Windsurf, ChatGPT, Claude, Gemini, Perplexity  
**Last Updated**: 2025-11-27

---

## 🎯 Project Context

**Type**: Production-ready n8n web scraping platform  
**Status**: Production (87% success rate, 5.3s latency, $2.88/1000 URLs)  
**Stack**: Docker Compose microservices (8 services)  
**Key Features**: Hybrid fallback (Firecrawl + Jina AI), smart anti-bot detection, Tor proxy, ML routing

---

## 📋 Core Principles

### 1. Token Efficiency
- **CRITICAL**: Always minimize token usage in suggestions
- Prefer compact code over verbose explanations
- Use inline comments sparingly (only for complex logic)
- Remove redundant whitespace in JSON/YAML

### 2. Production Standards
- All code must be production-ready (no TODOs, no placeholders)
- Include error handling for all external API calls
- Add logging for debugging (use `console.log` with context)
- Validate all environment variables at startup

### 3. Security First
- Never hardcode secrets (use `.env` variables)
- Always add `# @ai-ignore` comments above sensitive data
- Rotate credentials every 90 days (document in commit)
- Use 20+ character passwords (generate with `openssl rand -base64 24`)

### 4. Architecture Alignment
- Follow microservices pattern (8 services: n8n, postgres, redis, tor, ml-service, ollama, prometheus, grafana)
- Use Redis for rate limiting and caching
- Route through Tor for IP rotation
- Implement ML-based smart routing for scraper selection

---

## 🛠️ Code Style Guidelines

### JavaScript/TypeScript (n8n workflows, scrapers)
```javascript
// ✅ GOOD: Compact, production-ready
const scrape = async (url) => {
  try {
    const res = await fetch(url, { headers: HEADERS });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } catch (err) {
    console.error(`Scrape failed: ${url}`, err);
    return null;
  }
};

// ❌ BAD: Verbose, no error handling
const scrape = async (url) => {
  // This function scrapes a URL and returns the HTML content
  const response = await fetch(url);
  const html = await response.text();
  return html;
};
```

### Python (ml-service, scrapers)
```python
# ✅ GOOD: Type hints, error handling
def route_request(url: str, history: list[dict]) -> str:
    try:
        score = ml_model.predict(url, history)
        return "firecrawl" if score > 0.7 else "jina"
    except Exception as e:
        logger.error(f"Routing failed: {url}", exc_info=e)
        return "jina"  # Default fallback

# ❌ BAD: No types, no error handling
def route_request(url, history):
    score = ml_model.predict(url, history)
    return "firecrawl" if score > 0.7 else "jina"
```

### Docker Compose / YAML
```yaml
# ✅ GOOD: Minimal comments, compact
services:
  n8n:
    image: n8nio/n8n:latest
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}  # @ai-ignore
    depends_on: [postgres, redis]

# ❌ BAD: Verbose comments
services:
  n8n:
    # This is the n8n workflow orchestration service
    # It depends on postgres and redis
    image: n8nio/n8n:latest
    environment:
      # Encryption key for securing workflows
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
```

---

## 🔍 Context Priority for AI

**When suggesting code, prioritize reading these files first:**

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

---

## 🚨 Common Pitfalls to Avoid

### 1. Ignoring Rate Limits
```javascript
// ❌ BAD: No rate limiting
for (const url of urls) {
  await scrape(url);
}

// ✅ GOOD: Redis-based rate limiting
for (const url of urls) {
  await rateLimiter.wait('scraper', 100); // 100ms delay
  await scrape(url);
}
```

### 2. Hardcoding API Keys
```javascript
// ❌ BAD: Hardcoded key
const API_KEY = 'fc-abc123';

// ✅ GOOD: Environment variable with @ai-ignore
const API_KEY = process.env.FIRECRAWL_API_KEY; // @ai-ignore
```

### 3. Not Using Fallback
```javascript
// ❌ BAD: Single point of failure
const html = await firecrawl.scrape(url);

// ✅ GOOD: Hybrid fallback
let html = await firecrawl.scrape(url);
if (!html) {
  console.log(`Firecrawl failed, trying Jina: ${url}`);
  html = await jina.scrape(url);
}
```

### 4. Missing Tor Proxy
```javascript
// ❌ BAD: Direct request (IP gets blocked)
await fetch(url);

// ✅ GOOD: Route through Tor
await fetch(url, {
  agent: new SocksProxyAgent('socks5h://tor:9050')
});
```

---

## 📊 Testing Guidelines

### When suggesting tests:
1. Use Jest for JavaScript/TypeScript
2. Use pytest for Python
3. Mock external APIs (Firecrawl, Jina)
4. Test error handling (network failures, rate limits)
5. Validate environment variables at test startup

### Example Test Structure
```javascript
// ✅ GOOD: Comprehensive test
describe('scraper', () => {
  it('should scrape with Firecrawl', async () => {
    const html = await scrape('https://example.com');
    expect(html).toContain('<html>');
  });

  it('should fallback to Jina on Firecrawl failure', async () => {
    mockFirecrawl.mockRejectedValueOnce(new Error('Rate limit'));
    const html = await scrape('https://example.com');
    expect(html).toContain('<html>');
    expect(mockJina).toHaveBeenCalled();
  });
});
```

---

## 🔧 Workflow Patterns

### n8n Workflow Structure
- **Trigger**: Webhook (POST /scrape with {url, options})
- **Routing**: ML service decides Firecrawl vs Jina
- **Scraping**: Execute chosen scraper with Tor proxy
- **Fallback**: Retry with alternative on failure
- **Storage**: Save to PostgreSQL with metadata
- **Monitoring**: Send metrics to Prometheus

### Suggested Workflow Nodes (in order)
1. `Webhook` - Receive scrape request
2. `Code` - Validate URL and options
3. `HTTP Request` - Call ML service for routing
4. `IF` - Route to Firecrawl or Jina
5. `HTTP Request` - Execute scraper (with Tor proxy)
6. `Code` - Parse and clean HTML
7. `Postgres` - Store result
8. `Prometheus` - Send metrics
9. `Respond to Webhook` - Return result

---

## 🎓 Learning Resources

**When user asks for help:**
- n8n Docs: https://docs.n8n.io/
- Firecrawl API: https://docs.firecrawl.dev/
- Jina AI: https://jina.ai/reader/
- Docker Compose: https://docs.docker.com/compose/
- Prometheus: https://prometheus.io/docs/

**For advanced topics:**
- Anti-bot detection: `docs/HYBRID_FALLBACK_STRATEGY.md`
- Scraper implementation: `docs/NODRIVER_ENHANCED_V2.md`
- Architecture diagrams: `ARCHITECTURE.md`

---

## 🚀 Quick Commands Reference

```bash
# Start platform
docker-compose up -d --build

# View logs
docker-compose logs -f n8n

# Restart service
docker-compose restart n8n

# Stop platform
docker-compose down

# Full cleanup (delete volumes)
docker-compose down -v

# Run tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Generate password
openssl rand -base64 24

# View metrics
open http://localhost:9090  # Prometheus
open http://localhost:3000  # Grafana
```

---

## 📝 Commit Message Conventions

When suggesting commits:
```
feat: add new scraper for dynamic content
fix: resolve rate limiting issue in Firecrawl
refactor: optimize ML routing logic
docs: update architecture diagram
test: add integration tests for fallback
chore: update dependencies
```

---

## ⚙️ Environment Variables

**Always reference these from `.env`:**
```bash
# Required (20+ chars)
POSTGRES_PASSWORD=CHANGE_ME_LONG_PASSWORD
REDIS_PASSWORD=CHANGE_ME_LONG_PASSWORD
N8N_PASSWORD=CHANGE_ME_LONG_PASSWORD
TOR_CONTROL_PASSWORD=CHANGE_ME_LONG_PASSWORD
GRAFANA_PASSWORD=CHANGE_ME_LONG_PASSWORD

# API Keys (optional but recommended)
FIRECRAWL_API_KEY=fc-xxx  # @ai-ignore
JINA_API_KEY=jina-xxx      # @ai-ignore

# Services
N8N_USER=admin@example.com
POSTGRES_USER=n8n_user
POSTGRES_DB=n8n_db
REDIS_HOST=redis
TOR_HOST=tor
```

---

## 🎯 Performance Targets

When optimizing, aim for:
- **Success Rate**: ≥87%
- **Latency**: ≤5.3s average
- **Cost**: ≤$2.88/1000 URLs
- **Cloudflare Bypass**: ≥90%
- **Memory**: No leaks (stable over 24h)

---

**Built with ❤️ by KomarovAI | AI-Optimized v2.0 🧠**
