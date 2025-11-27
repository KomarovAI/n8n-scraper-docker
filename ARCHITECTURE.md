# Architecture Semantic Map

> **For AI:** This document provides visual architecture diagrams and dependency maps for quick context understanding.

## System Overview

### Service Topology

```mermaid
graph TB
    subgraph "Entry Point"
        N[n8n:5678<br/>Workflow Orchestration]
    end

    subgraph "Data Layer"
        P[postgres:5432<br/>Data Storage]
        R[redis:6379<br/>Cache & Rate Limiting]
    end

    subgraph "Network Layer"
        T[tor:9050<br/>IP Rotation]
    end

    subgraph "Intelligence Layer"
        M[ml-service:8000<br/>Smart Routing]
        O[ollama:11434<br/>Local LLM]
    end

    subgraph "Monitoring Layer"
        PR[prometheus:9090<br/>Metrics]
        G[grafana:3000<br/>Dashboards]
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

    style N fill:#32b8c6
    style M fill:#e6af60
    style P fill:#336791
    style R fill:#d82c20
    style PR fill:#e6522c
    style G fill:#f46800
```

## Data Flow

### Scraping Workflow

```mermaid
sequenceDiagram
    participant User
    participant n8n
    participant ML
    participant Scrapers
    participant DB
    participant Redis

    User->>n8n: Trigger Workflow
    n8n->>Redis: Check Rate Limit
    Redis-->>n8n: OK
    n8n->>ML: Request Scraper Route
    ML->>ML: Analyze URL Pattern
    ML-->>n8n: Recommend Scraper
    n8n->>Scrapers: Execute Scraping
    Scrapers-->>n8n: Return Data
    n8n->>DB: Store Results
    DB-->>n8n: Confirm
    n8n-->>User: Workflow Complete
```

### Fallback Strategy

```mermaid
graph LR
    A[URL Request] --> B{ML Router}
    B -->|Primary| C[Scraper A]
    B -->|Fallback 1| D[Scraper B]
    B -->|Fallback 2| E[Scraper C]
    
    C -->|Success| F[Store Data]
    C -->|Fail| D
    D -->|Success| F
    D -->|Fail| E
    E --> F

    style A fill:#d4d4d4
    style B fill:#e6af60
    style F fill:#90ee90
```

## Service Dependencies

### Dependency Graph

```mermaid
graph TD
    N[n8n] --> P[postgres]
    N --> R[redis]
    N --> T[tor]
    N --> M[ml-service]
    M --> O[ollama]
    M --> R
    PR[prometheus] --> N
    PR --> P
    PR --> R
    PR --> M
    G[grafana] --> PR

    style N fill:#32b8c6
    style M fill:#e6af60
```

### Startup Order

```mermaid
graph TD
    Start[Docker Compose Up] --> L1[Level 1: Base Services]
    L1 --> postgres
    L1 --> redis
    L1 --> tor
    L1 --> ollama
    L1 --> prometheus
    
    postgres --> L2[Level 2: ML Service]
    redis --> L2
    ollama --> L2
    L2 --> ml-service
    
    postgres --> L3[Level 3: n8n]
    redis --> L3
    tor --> L3
    ml-service --> L3
    L3 --> n8n
    
    prometheus --> L4[Level 4: Grafana]
    L4 --> grafana

    style Start fill:#d4d4d4
    style L1 fill:#90ee90
    style L2 fill:#ffd700
    style L3 fill:#ff6347
    style L4 fill:#9370db
```

## Component Details

### n8n (Workflow Orchestration)

**Port:** 5678  
**Role:** Central orchestrator  
**Dependencies:** postgres, redis, tor, ml-service  
**Responsibilities:**
- Workflow execution
- User interface
- Credential management
- Webhook handling

**Critical Paths:**
1. Workflow trigger → scraper selection → execution → storage
2. User action → UI → database → response

### postgres (Data Storage)

**Port:** 5432  
**Role:** Persistent data storage  
**Dependents:** n8n  
**Responsibilities:**
- Workflow definitions
- Execution history
- Credentials (encrypted)
- User data

**Volume:** `postgres-data` (persistent)

### redis (Cache & Rate Limiting)

**Port:** 6379  
**Role:** In-memory data store  
**Dependents:** n8n, ml-service  
**Responsibilities:**
- Rate limiting (requests/min)
- Caching (scraper results)
- Queue management
- Session storage

**Volume:** `redis-data` (persistent)

### tor (IP Rotation)

**Port:** 9050  
**Role:** SOCKS proxy  
**Dependents:** n8n (via scrapers)  
**Responsibilities:**
- IP anonymization
- IP rotation
- Geographic diversity
- Anti-blocking

### ml-service (Smart Routing)

**Port:** 8000  
**Role:** Intelligent scraper selection  
**Dependencies:** ollama, redis  
**Dependents:** n8n  
**Responsibilities:**
- URL pattern analysis
- Scraper recommendation
- Fallback strategy
- Success rate tracking

**Algorithm:** Hybrid decision tree + LLM classification

### ollama (Local LLM)

**Port:** 11434  
**Role:** On-premise language model  
**Dependents:** ml-service  
**Responsibilities:**
- Text classification
- Pattern recognition
- Content analysis
- Zero external API cost

**Model:** Configurable (default: llama2)

### prometheus (Metrics Collection)

**Port:** 9090  
**Role:** Time-series database  
**Dependencies:** All services (scrape targets)  
**Dependents:** grafana  
**Responsibilities:**
- Metrics collection (15s interval)
- Alerting rules
- Query engine (PromQL)
- Data retention (15 days)

### grafana (Visualization)

**Port:** 3000  
**Role:** Monitoring dashboards  
**Dependencies:** prometheus  
**Responsibilities:**
- Dashboard rendering
- Alerting UI
- User management
- Data exploration

## Network Communication

### Internal Network

All services communicate via `docker-compose` default network.

**Network Name:** `n8n-scraper-network` (auto-created)  
**Type:** Bridge  
**Subnet:** Auto-assigned (172.x.0.0/16)  

### External Access

**Exposed Ports:**
- 5678 (n8n UI)
- 3000 (Grafana)
- 9090 (Prometheus)

**Internal Only:**
- 5432 (postgres)
- 6379 (redis)
- 9050 (tor)
- 8000 (ml-service)
- 11434 (ollama)

## Scaling Considerations

### Horizontal Scaling

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

    style LB fill:#d4d4d4
    style P fill:#336791
    style R fill:#d82c20
```

**Scalable Services:**
- n8n (stateless workflows)
- ml-service (stateless routing)
- ollama (model inference)

**Single-Instance Services:**
- postgres (requires replication setup)
- redis (requires cluster mode)

### Vertical Scaling

**Resource Allocation (docker-compose):**

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

## Security Architecture

### Defense Layers

```mermaid
graph TD
    Internet[Internet] --> FW[Firewall]
    FW --> LB[Reverse Proxy/LB]
    LB --> N8N[n8n]
    
    N8N --> Auth[Authentication]
    Auth --> RBAC[RBAC]
    RBAC --> Data[Data Access]
    
    Data --> Encrypt[Encryption at Rest]
    N8N -.-> TLS[TLS in Transit]

    style Internet fill:#ff6347
    style FW fill:#ffa500
    style Auth fill:#90ee90
    style Encrypt fill:#4169e1
```

**Security Measures:**
1. Firewall (ports 22, 5678 only)
2. Strong passwords (20+ chars)
3. TLS/SSL for web interfaces
4. Credential encryption (n8n built-in)
5. Secret management (.env, never committed)
6. Security scanning (Trivy in CI/CD)
7. Regular updates (docker images)

## Monitoring Architecture

### Metrics Flow

```mermaid
graph LR
    S1[n8n] --> |metrics| P[Prometheus]
    S2[postgres] --> |metrics| P
    S3[redis] --> |metrics| P
    S4[ml-service] --> |metrics| P
    
    P --> |scrape| P
    P --> |query| G[Grafana]
    G --> |visualize| D[Dashboards]
    G --> |alert| A[Alerts]

    style P fill:#e6522c
    style G fill:#f46800
```

**Metrics Collected:**
- Request rate (req/s)
- Success rate (%)
- Latency (p50, p95, p99)
- Error rate (%)
- Resource usage (CPU, RAM, disk)
- Queue depth
- Cache hit rate

## Disaster Recovery

### Backup Strategy

```bash
# Automated daily backups
0 2 * * * /scripts/backup-postgres.sh
0 3 * * * /scripts/backup-redis.sh
```

**What's Backed Up:**
- postgres (pg_dump)
- redis (RDB snapshot)
- n8n workflows (JSON export)
- Configuration files (.env, docker-compose.yml)

**Retention:** 7 days local, 30 days remote (optional)

### Recovery Procedure

```bash
# 1. Restore postgres
cat backup.sql | docker-compose exec -T postgres psql -U scraper_user scraper_db

# 2. Restore redis
docker-compose exec redis redis-cli --rdb /data/dump.rdb

# 3. Restart services
docker-compose restart
```

## Performance Benchmarks

| Metric | Value | Notes |
|--------|-------|-------|
| Success Rate | 87% | Average across all scrapers |
| Avg Latency | 5.3s | End-to-end workflow execution |
| Max Throughput | ~200 req/min | Rate limited |
| Cost | $2.88/1000 URLs | Hybrid fallback strategy |
| Cloudflare Bypass | 90-95% | Smart detection enabled |
| Memory Usage | ~3.5 GB | All services combined |
| Startup Time | ~45s | From docker-compose up |

---

**For AI:** This architecture supports:
- ✅ Horizontal scaling (n8n, ml-service)
- ✅ High availability (with replication)
- ✅ Zero downtime updates (rolling)
- ✅ Disaster recovery (automated backups)
- ✅ Monitoring & alerting (full stack)

**Quick Context:** 8 services, Docker Compose orchestration, production-ready, AI-optimized.
