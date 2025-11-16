# Architecture Overview

## System Design

### Components

1. **N8N Workflow Engine** - Orchestration layer
2. **GitHub Actions Workers** - Async scraping execution
3. **PostgreSQL** - Data persistence
4. **VictoriaMetrics** - Metrics collection

### Data Flow

```
Client Request
  ↓
[Webhook + Header Auth]
  ↓
[Input Validator]
  ├─ SSRF Protection
  ├─ Schema Validation
  └─ Site Detection
  ↓
[Smart Router]
  ├─ Simple Sites → HTTP Request
  ├─ JS-Heavy Sites → Playwright
  ├─ Protected Sites → Nodriver (GitHub Actions)
  └─ All Failed → Firecrawl API
  ↓
[Quality Check]
  ├─ Size validation
  ├─ Content validation
  └─ Retry if failed
  ↓
[PostgreSQL Storage]
  └─ Upsert with deduplication
  ↓
[Response]
```

### Security Features

- **SSRF Protection**: Blocks localhost, private IPs, cloud metadata endpoints
- **Header Authentication**: API key validation
- **Rate Limiting**: Traefik middleware
- **Input Validation**: Pydantic schemas

### Scalability

- Horizontal scaling via k8s replicas
- Async GitHub Actions workers
- PostgreSQL connection pooling
- Batch processing support

### Monitoring

- Prometheus metrics export
- Structured JSON logging
- Grafana dashboards
- Alert rules for failures
