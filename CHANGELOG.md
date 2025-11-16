# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-16

### 🔒 Security (BREAKING CHANGES)

- **CRITICAL**: Fixed script injection vulnerability in GitHub Actions workflows
- Added explicit minimal permissions to all workflows (principle of least privilege)
- Implemented Pydantic-based input validation with comprehensive SSRF protection
- Added artifact integrity verification before processing
- Deprecated insecure `*-enhanced.yml` workflows (removed in v2.0.0)

### ✨ Added

- New secured workflows: `nodriver-batch-secured.yml`, `playwright-batch-secured.yml`
- Input validation scripts: `validate_input.py`, `validate_input.js`
- Results verification: `verify_results.py`
- CI/CD pipeline with automated testing and security scanning (CodeQL, Trivy)
- Unit tests for validation logic (pytest, jest)
- Kubernetes HorizontalPodAutoscaler with optimal scaling parameters
- Kubernetes PodDisruptionBudget for high availability
- NetworkPolicy for network isolation and egress control
- Redis deployment for caching and rate limiting
- Prometheus alert rules for monitoring
- Rate limiting integration with Redis
- Circuit breaker pattern for external API calls
- Checkpointing for long-running workflows
- Correlation IDs in structured logging
- Prometheus metrics export from scrapers

### 🔧 Changed

- **BREAKING**: N8N workflow now requires Redis connection for rate limiting
- **BREAKING**: All GitHub Actions now use SHA-pinned versions
- **BREAKING**: NetworkPolicy requires Calico/Cilium for FQDN-based egress filtering
- Updated Python dependencies with pinned versions and hashes
- Redis configuration optimized for LRU eviction and persistence
- HPA configured with dual metrics (CPU 70%, Memory 80%)
- Workflow timeouts increased to 30 minutes with proper cleanup
- Artifact retention reduced to 7 days to save storage costs

### 📚 Documentation

- Added comprehensive deployment guide
- Security best practices documentation
- Migration guide from v1.x to v2.0
- Troubleshooting runbook
- Updated README with new architecture

### 🐛 Fixed

- Fixed egress NetworkPolicy allowing unrestricted HTTPS access
- Fixed missing JavaScript validation for Playwright workflows
- Fixed Redis single point of failure with replication
- Fixed lack of SHA pinning in GitHub Actions
- Fixed missing unit tests causing CI failures

### ⚠️ Deprecated

- `nodriver-batch-enhanced.yml` - use `nodriver-batch-secured.yml`
- `playwright-batch-enhanced.yml` - use `playwright-batch-secured.yml`
- Direct `repository_dispatch` triggers - use `workflow_dispatch` with validation

### 🗑️ Removed

- Insecure workflows with direct input interpolation
- Unrestricted egress rules in NetworkPolicy

## [1.0.0] - 2025-11-16

### Added

- Initial production scraper workflow with multi-tier architecture
- Smart routing: HTTP → Playwright → Nodriver → Firecrawl
- Basic SSRF protection and input validation
- GitHub Actions async workers
- Kubernetes deployment manifests
- Basic monitoring and logging

### Security Issues (Fixed in v2.0.0)

- ❌ Script injection vulnerability in GitHub Actions
- ❌ Insufficient SSRF protection (missing IPv6, cloud metadata)
- ❌ Overly permissive GitHub token permissions
- ❌ Missing input validation
- ❌ No artifact integrity checks

---

## Migration Guide: v1.x → v2.0

### Required Actions

1. **Update N8N Workflow**: Import new `workflow-scraper-secured.json`
2. **Deploy Redis**: Apply `k8s/redis.yaml` before updating N8N
3. **Update Secrets**: Add Redis connection string to N8N environment
4. **Replace Workflow References**: Change `*-enhanced.yml` to `*-secured.yml`
5. **Apply NetworkPolicy**: Ensure cluster has Calico/Cilium for FQDN filtering
6. **Update Monitoring**: Apply new Prometheus alert rules

### Breaking Changes

- Workflows now require `REDIS_URL` environment variable
- Old webhook endpoints need header authentication
- Batch size limited to 100 URLs (was unlimited)
- Artifact retention changed from 1 day to 7 days

### Rollback Plan

If issues occur:
1. Revert to main branch commit `e9aa8bd`
2. Remove NetworkPolicy: `kubectl delete netpol n8n-scraper-netpol`
3. Scale down Redis: `kubectl scale deployment redis --replicas=0`
4. Restore old N8N workflow from backup
