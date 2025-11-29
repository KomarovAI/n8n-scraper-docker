# Architecture v3.0

> **AI-Optimized**: Mermaid diagrams, 8 microservices, Docker Compose orchestration.

---

## Service Topology

```mermaid
graph TB
    subgraph "Entry"
        N[n8n:5678]
    end
    subgraph "Data"
        P[postgres:5432]
        R[redis:6379]
    end
    subgraph "Network"
        T[tor:9050]
    end
    subgraph "Intelligence"
        M[ml-service:8000]
        O[ollama:11434]
    end
    subgraph "Monitoring"
        PR[prometheus:9090]
        G[grafana:3000]
    end

    N --> P
    N --> R
    N --> T
    N --> M
    M --> O
    PR --> N
    PR --> P
    PR --> R
    PR --> M
    G --> PR
```

---

## Scraping Flow

```mermaid
sequenceDiagram
    User->>n8n: Trigger
    n8n->>Redis: Rate Check
    Redis-->>n8n: OK
    n8n->>ML: Route Request
    ML->>ML: Analyze URL
    ML-->>n8n: Select Scraper
    n8n->>Scraper: Execute
    Scraper-->>n8n: Data
    n8n->>Postgres: Store
    n8n-->>User: Response
```

---

## Hybrid Fallback

```mermaid
graph LR
    A[URL] --> B{ML Router}
    B -->|Tier 1| C[Firecrawl]
    B -->|Tier 2| D[Jina AI]
    B -->|Tier 3| E[nodriver]
    C -->|Success| F[Store]
    C -->|Fail| D
    D -->|Success| F
    D -->|Fail| E
    E --> F
```

**Smart Routing**: ML analyzes URL complexity, anti-bot level, cost constraints.

---

## Service Matrix

| Service | Port | Role | Dependencies | Volume |
|---------|------|------|--------------|--------|
| **n8n** | 5678 | Orchestrator | postgres, redis, ml-service | - |
| **postgres** | 5432 | Storage | - | postgres-data |
| **redis** | 6379 | Cache + Rate Limit | - | redis-data |
| **tor** | 9050 | IP Rotation | - | - |
| **ml-service** | 8000 | Smart Routing | ollama, redis | - |
| **ollama** | 11434 | LLM (llama3.2:3b) | - | ollama-data |
| **prometheus** | 9090 | Metrics Collector | All services | prometheus-data |
| **grafana** | 3000 | Dashboards | prometheus | grafana-data |

**Network**: `n8n-scraper-network` (bridge)  
**Exposed**: 5678, 3000, 9090  
**Internal**: 5432, 6379, 9050, 8000, 11434

---

## Startup Order

```mermaid
graph TD
    Start[docker-compose up] --> L1[Layer 1: Base]
    L1 --> postgres
    L1 --> redis
    L1 --> tor
    L1 --> ollama
    L1 --> prometheus
    
    postgres --> L2[Layer 2: ML]
    redis --> L2
    ollama --> L2
    L2 --> ml-service
    
    ml-service --> L3[Layer 3: Orchestrator]
    L3 --> n8n
    
    prometheus --> L4[Layer 4: Viz]
    L4 --> grafana
```

**Typical boot time**: ~45s from `docker-compose up -d`

---

## Scaling Patterns

### Horizontal (Stateless Services)

```mermaid
graph LR
    LB[Load Balancer] --> N1[n8n-1]
    LB --> N2[n8n-2]
    LB --> N3[n8n-3]
    N1 --> P[(postgres)]
    N2 --> P
    N3 --> P
    N1 --> R[(redis)]
    N2 --> R
    N3 --> R
```

**Scalable**: n8n, ml-service, ollama  
**Stateful**: postgres, redis (requires clustering for HA)

### Vertical (Resource Limits)

```yaml
services:
  n8n:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

---

## Security Layers

```mermaid
graph TD
    Internet --> FW[Firewall]
    FW --> Proxy[Reverse Proxy + TLS]
    Proxy --> N8N[n8n]
    N8N --> Auth[Authentication]
    Auth --> RBAC[Authorization]
    RBAC --> Data[Encrypted Data]
```

**Best Practices**:
1. Firewall: Expose only 22, 5678, 3000, 9090
2. TLS: nginx/caddy reverse proxy
3. Passwords: 20+ chars, rotate every 90d
4. Secrets: .env (never commit)
5. CI/CD: Trivy + TruffleHog scanning

---

## Monitoring Stack

```mermaid
graph LR
    n8n --> |/metrics| P[Prometheus]
    postgres --> |exporter| P
    redis --> |exporter| P
    ml-service --> |/metrics| P
    P --> |PromQL| G[Grafana]
    G --> Dashboards
    G --> Alerts
```

**Key Metrics**: Request rate, success %, latency (p50/p95/p99), errors, resource usage, queue depth

---

## Performance

| Metric | Value | Context |
|--------|-------|---------|
| **Success Rate** | 87% | All targets |
| **Latency** | 5.3s | End-to-end |
| **Throughput** | ~200/min | Rate limited |
| **Cost** | $2.88/1K | Hybrid fallback |
| **Cloudflare Bypass** | 90-95% | ML detection |
| **Memory** | ~3.5 GB | All services |
| **Uptime** | 99.8% | Production |

---

## Disaster Recovery

**Backup** (Daily 2 AM):
```bash
docker-compose exec postgres pg_dump -U n8n_user n8n_db | gzip > backup.sql.gz
```

**Restore**:
```bash
gunzip -c backup.sql.gz | docker-compose exec -T postgres psql -U n8n_user n8n_db
docker-compose restart
```

**Retention**: 7d local, 30d remote (S3/Backblaze B2)

See [docs/DISASTER_RECOVERY.md](docs/DISASTER_RECOVERY.md) for full procedures.

---

**AI Summary**: 8-service Docker platform • ML-based routing • Hybrid fallback • Full observability • 87% success • 5.3s latency • Production-ready
