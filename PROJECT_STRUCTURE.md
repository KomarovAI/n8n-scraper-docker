# 📁 PROJECT STRUCTURE - Navigation Map

> **AI-Optimized Project Structure**  
> Quick navigation and context understanding for AI assistants

## 📊 Overview

```
n8n-scraper-docker/
├── 🤖 AI Configuration
├── 🐳 Docker Setup
├── 📚 Documentation
├── 🔧 Application Code
├── 🧪 Testing
├── 📊 Monitoring
└── ⚙️  Infrastructure
```

---

## 🤖 AI Configuration

| File | Purpose | Priority |
|------|---------|----------|
| `.ai-optimized` | AI optimization flags | 🔴 High |
| `.aimeta.json` | AI metadata & context | 🔴 High |
| `.aiignore` | AI context exclusions | 🔴 High |
| `.cursorrules` | Cursor IDE AI rules | 🟡 Medium |
| `.windsurfrules` | Windsurf IDE AI rules | 🟡 Medium |
| `AI_MANIFEST.md` | AI project manifest | 🔴 High |

**AI Context:**  
These files optimize how AI assistants understand and work with the project.

---

## 🐳 Docker Setup

| File/Dir | Purpose | Key Files |
|----------|---------|----------|
| `Dockerfile.n8n-enhanced` | Main n8n image | 🔴 Critical |
| `docker-compose.yml` | Service orchestration | 🔴 Critical |
| `.dockerignore` | Build optimization | 🟡 Important |
| `.env.example` | Environment template | 🔴 Critical |
| `proxy/` | Tor & proxy configs | 🟢 Feature |

**Services:**
- n8n (workflow automation)
- PostgreSQL (database)
- Redis (caching)
- Tor (anonymity)
- Prometheus + Grafana (monitoring)

---

## 📚 Documentation

### Root Documentation

| File | Purpose | Audience |
|------|---------|----------|
| `README.md` | Project overview | 👥 All |
| `QUICKSTART.md` | Quick start guide | 🚀 Users |
| `ARCHITECTURE.md` | System architecture | 🏗️ Developers |
| `AI_MANIFEST.md` | AI integration guide | 🤖 AI Tools |

### `/docs` - Detailed Guides

| File | Topic | Type |
|------|-------|------|
| `INDEX.md` | Documentation index | 📖 Navigation |
| `CI_CD_OPTIMIZATION.md` | CI/CD best practices | 🔧 Technical |
| `ANTI_DETECTION_GUIDE.md` | Scraping stealth | 🔒 Technical |
| `HYBRID_FALLBACK_STRATEGY.md` | Scraper failover | 🔄 Technical |
| `NODRIVER_ENHANCED_V2.md` | NoDriver setup | 🌐 Technical |
| `FIRECRAWL_TO_JINA_MIGRATION.md` | Migration guide | 🔄 Migration |
| `RATE_LIMITING_GUIDE.md` | Rate limiting | ⚡ Technical |

**Navigation:**
Start with `docs/INDEX.md` for full documentation map.

---

## 🔧 Application Code

### Core Directories

```
├── nodes/              # Custom n8n nodes
├── scrapers/           # Web scraping logic
├── workflows/          # n8n workflow definitions
├── ml/                 # ML service (if enabled)
├── utils/              # Shared utilities
└── scripts/            # Automation scripts
```

### `nodes/` - Custom n8n Nodes

**Purpose:** Extend n8n with custom functionality  
**Tech:** JavaScript/TypeScript  
**Key Files:** Node implementations, credentials, icons

### `scrapers/` - Web Scraping Logic

**Purpose:** Scraping engines and strategies  
**Tech:** Python (nodriver, requests, beautifulsoup)  
**Strategies:**
- Static scraping (requests)
- Dynamic scraping (nodriver)
- Hybrid fallback

### `workflows/` - n8n Workflows

**Purpose:** Pre-built automation workflows  
**Format:** JSON (n8n workflow format)  
**Examples:** Scraping, data processing, notifications

### `ml/` - ML Service

**Purpose:** Optional ML/AI capabilities  
**Tech:** Python, transformers, scikit-learn  
**Features:** Text analysis, classification

### `utils/` - Shared Utilities

**Purpose:** Reusable helper functions  
**Common:** Logging, config, validation

### `scripts/` - Automation Scripts

**Purpose:** Deployment, maintenance, testing  
**Examples:** Setup, backup, health checks

---

## 🧪 Testing

### `/tests` Structure

```
tests/
├── smoke/              # Smoke tests
├── n8n/                # n8n E2E tests
├── webhooks/           # Webhook tests
└── subworkflows/       # Subworkflow tests
```

**Testing Levels:**
1. 🔥 **Smoke Tests** - Basic functionality
2. 🔬 **Integration Tests** - Service interaction
3. 🌐 **E2E Tests** - Full workflow validation
4. ⚡ **Performance Tests** - Load & speed
5. 🔒 **Security Tests** - Trivy, secrets

**CI/CD:** See `.github/workflows/ci-test.yml`

---

## 📊 Monitoring

### `/monitoring` Directory

```
monitoring/
├── prometheus.yml      # Metrics collection
├── grafana/            # Dashboards
│   ├── dashboards/     # JSON dashboards
│   └── datasources/    # Data sources
└── alerts/             # Alert rules
```

**Stack:**
- Prometheus (metrics)
- Grafana (visualization)
- Node Exporter (system metrics)
- Redis Exporter (Redis metrics)
- PostgreSQL Exporter (DB metrics)

**Dashboards:**
- System overview
- n8n performance
- Database health
- Redis cache stats

---

## ⚙️ Infrastructure

### `.github/` - CI/CD

```
.github/
└── workflows/
    ├── ci-test.yml     # Main CI/CD pipeline
    └── *.yml           # Additional workflows
```

**CI/CD Features:**
- 🔍 Code quality checks
- 🔒 Security scanning
- 🐳 Docker image builds
- 🧪 Automated testing
- 🤖 CTRF AI reporting
- 📦 Artifact generation

**Test Reports:**
Downloadable from Actions → Artifacts → `ctrf-test-report-*`

### `db/` - Database

```
db/
├── init/               # Initial setup
└── migrations/         # Schema migrations
```

**Database:** PostgreSQL  
**Migrations:** SQL scripts for version control

---

## 🎯 Quick Navigation for AI

### New to Project?
1. Start: `README.md` → `QUICKSTART.md`
2. Architecture: `ARCHITECTURE.md`
3. AI Integration: `AI_MANIFEST.md`
4. Detailed Docs: `docs/INDEX.md`

### Working on Feature?
1. Code: `/nodes`, `/scrapers`, `/workflows`
2. Tests: `/tests`
3. Docs: Update relevant `/docs/*.md`

### Debugging?
1. Logs: Check Docker Compose logs
2. Monitoring: Grafana dashboards
3. Tests: Run specific test suite
4. CI/CD: Check `.github/workflows/ci-test.yml`

### Need Context?
1. Project structure: This file (you're here!)
2. AI metadata: `.aimeta.json`
3. Documentation index: `docs/INDEX.md`
4. Architecture overview: `ARCHITECTURE.md`

---

## 📏 Project Stats

- **Total Directories:** ~15
- **Documentation Files:** 12+
- **Test Suites:** 15
- **CI/CD Jobs:** 14 (optimized from 16)
- **Services:** 9 (n8n, DB, Redis, Tor, monitoring)
- **AI Optimization Level:** 95/100 ⭐

---

## 🔄 Related Files

- [README.md](./README.md) - Project overview
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System design
- [AI_MANIFEST.md](./AI_MANIFEST.md) - AI integration
- [docs/INDEX.md](./docs/INDEX.md) - Documentation index
- [.aiignore](./.aiignore) - AI context filter
- [.github/workflows/ci-test.yml](./.github/workflows/ci-test.yml) - CI/CD pipeline

---

**Last Updated:** 2025-11-27  
**Maintained for:** AI Assistants, Developers, New Contributors
