# N8N Smart Web Scraper - Production Ready

Production-grade web scraping workflow with intelligent fallback system.

## 🎯 Features

- **Multi-tier scraping**: HTTP → Playwright → Nodriver → Firecrawl
- **Anti-bot bypass**: Cloudflare, Datadome, Akamai handling
- **SSRF Protection**: Built-in security validation
- **Quality checks**: Data validation before storage
- **PostgreSQL storage**: Persistent data with deduplication
- **Monitoring**: Structured logs + Prometheus metrics

## 🏗️ Architecture

```
Webhook (Header Auth)
  ↓
Input Validator (SSRF Protection)
  ↓
Smart Router
  ├─→ Basic HTTP (simple sites)
  ├─→ Playwright (JS-heavy sites)
  ├─→ Nodriver GitHub Actions (protected sites)
  └─→ Firecrawl Fallback (when all fail)
  ↓
Quality Check
  ↓
PostgreSQL Storage
  ↓
Response
```

## 🚀 Quick Start

1. Import `workflow-scraper-main.json` into N8N
2. Configure credentials:
   - Header Auth for webhook
   - GitHub API token
   - Firecrawl API key
   - PostgreSQL connection
3. Set environment variables
4. Activate workflow

## 📡 API Usage

```bash
curl -X POST https://your-n8n.com/webhook/scrape \
  -H "X-API-Key: your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "selector": "article",
    "waitFor": ".content"
  }'
```

## 🔧 Configuration

See `docs/CONFIGURATION.md` for detailed setup instructions.
