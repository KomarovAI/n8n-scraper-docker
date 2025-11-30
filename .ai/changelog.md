# Changelog - Critical Changes

> **Purpose**: Track critical architectural changes, breaking changes, and major fixes for AI assistants.

---

## 2025-11-30

### 🔴 CRITICAL: Workflow Architecture Fix

**Problem**: CI/CD tests failing with HTTP 500 on webhook endpoint `/webhook/scrape`

**Root Cause**: Missing explicit `Respond to Webhook` node in workflow architecture

**Solution Applied**:
- ✅ Added `Respond to Webhook` node
- ✅ Changed `responseMode: "lastNode"` → `"responseNode"`
- ✅ Fixed data access patterns (`$input.item.json.body`)
- ✅ Implemented error handling flow (IF node + error branches)
- ✅ Added `continueOnFail: true` for HTTP Request node

**Impact**: Success rate 0% → ~95%

**Full Details**: See `AUDIT-REPORT.md` sections "Root Cause Analysis" and "Применённые исправления"

**Related Commits**:
- `fd618b9` - fix: Исправлен workflow - добавлен Respond node
- `c225e58` - fix: Layer 1 webhook verification
- `1926479` - fix: Layer 2 test script preflight

---

### ⚠️ BREAKING: Authentication Method Change

**Changed**: n8n 1.0+ no longer supports Basic Auth

**Migration Required**:
- ❌ Remove all Basic Auth usage
- ✅ Use User Management API instead
- ✅ Update environment variables:
  - `N8N_USER` = owner account email
  - `N8N_PASSWORD` = owner account password
  - `N8N_API_KEY` = manual API key creation

**Documentation**: `docs/CRITICAL_FIXES_2025-11-30.md`

**Official Source**: https://docs.n8n.io/1-0-migration-checklist/

---

### ✅ Feature: ML Service Optional

**Changed**: ML service no longer blocks n8n startup

**Benefits**:
- Graceful degradation if ML service unavailable
- Faster startup times
- Better resilience

**Implementation**: 
- ML service marked as optional dependency
- Increased healthcheck timeouts
- Fallback to default routing if ML unavailable

---

## 2025-11-27

### 🔴 CRITICAL: CVE-2025-62725 Mitigation

**Vulnerability**: Docker Compose < v2.40.2 privilege escalation

**Severity**: HIGH

**Required Action**: Upgrade Docker Compose to v2.40.2+

**Verification**:
```bash
docker compose version
# Must show v2.40.2 or higher
```

**Documentation**: `SECURITY.md` section "Known Vulnerabilities"

---

## 2025-11-25

### ✅ Feature: Webhook Readiness Fix

**Problem**: GitHub Actions tests failing with race condition (~0.5s gap, needed 2-5s)

**Solution Implemented**:
- ✅ Layer 1: Smart webhook registration verification (API polling)
- ✅ Layer 2: Pre-flight check with retry logic (3 attempts × 3s)
- ✅ Documentation: Production-grade guide

**Results**:
- Success rate: 0% → 85-95%
- Added: 2-17s adaptive wait (acceptable for reliability)

**Documentation**: `docs/WEBHOOK_READINESS_FIX.md`

---

## Version History

| Version | Date | Major Changes |
|---------|------|---------------|
| **v3.0.2** | 2025-11-30 | Workflow architecture fix, reusable workflows |
| **v3.0.1** | 2025-11-27 | CVE-2025-62725 mitigation |
| **v3.0.0** | 2025-11-25 | Webhook readiness fix, parallel testing |
| **v2.1.0** | 2025-11-20 | ML service integration |
| **v2.0.0** | 2025-11-15 | Hybrid fallback strategy |

---

## Quick Reference for AI Assistants

### Current Stable Architecture

**n8n Workflows** (as of v3.0.2):
- ✅ All webhooks use `responseMode: "responseNode"`
- ✅ Explicit `Respond to Webhook` nodes
- ✅ Error handling via IF nodes
- ✅ SSRF protection in Input Validator
- ✅ `continueOnFail: true` for external calls

**Authentication** (n8n 1.0+):
- ✅ User Management API (owner account)
- ✅ API Key authentication for workflow API
- ❌ Basic Auth removed (deprecated)

**CI/CD Pipeline**:
- ✅ Parallel testing (14 tests, ~2.5min runtime)
- ✅ Webhook readiness verification (2-17s adaptive)
- ✅ Self-hosted runner support (artikk)
- ✅ Artifact compression (75-99% reduction)

---

## Breaking Changes Checklist

When making breaking changes, update:
- [ ] This changelog (`CHANGELOG.md`)
- [ ] `.ai/context.md` (if architecture changes)
- [ ] `.ai/instructions.md` (if patterns change)
- [ ] Main `README.md` (user-facing changes)
- [ ] Relevant `docs/*.md` files
- [ ] Workflow `meta.version` fields
- [ ] `docker-compose.yml` (if service changes)

---

**Maintained by**: @KomarovAI  
**Last Updated**: 2025-11-30  
**Format Version**: 1.0
