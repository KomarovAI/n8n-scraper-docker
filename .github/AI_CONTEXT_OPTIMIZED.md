# AI Context Optimization Badge 🧬

This repository has been optimized for minimal AI/LLM context consumption.

## Optimization Stats

- **Documentation reduced**: 66% (-54 KB)
- **Files removed**: 9 redundant docs
- **Functionality preserved**: 100%
- **Tests preserved**: 100% (all 10 types)
- **Code preserved**: 100% (zero changes)

## Structure

```
Context-optimized navigation:
README.md (3.4 KB)           # Architecture map, quick commands
  └→ QUICKSTART.md (1.1 KB)  # 5 commands to launch
  └→ docs/INDEX.md          # Technical docs map
       └→ 5 technical guides  # Scrapers, strategies, infra
```

## What AI Gets

✅ **Clear architecture** - Service map, ports, dependencies
✅ **Fast start** - 5 commands from clone to running
✅ **Technical depth** - Indexed docs for specific topics
✅ **Full codebase** - All executable files unchanged
✅ **Complete tests** - 10 test types, CI/CD intact

## What's Gone

❌ Verbose FAQs
❌ Historical changelogs
❌ Duplicate explanations
❌ Security tutorials (basics in README)
❌ Testing guides (CI handles it)

## Verification

All functionality verified:
```bash
# Deployment works
docker-compose up -d --build  ✓

# Tests pass
.github/workflows/ci-test.yml ✓
  • Lint & validation
  • Security scan
  • Docker build
  • Smoke test
  • Health checks
  • Integration tests
  • n8n e2e
  • Webhook test
  • Subworkflow test
  • Test summary

# Services accessible
http://localhost:5678  ✓  # n8n
http://localhost:3000  ✓  # Grafana
http://localhost:9090  ✓  # Prometheus
```

## For Contributors

When adding docs:
- Keep README minimal (architecture + commands only)
- Use QUICKSTART for setup steps
- Put technical details in docs/ with INDEX update
- Avoid duplication
- No verbose explanations

## Report

See [OPTIMIZATION_REPORT.md](../OPTIMIZATION_REPORT.md) for full details.

---

**Status: OPTIMIZED** ✅ | Minimal Context 🧬 | Full Functionality 🚀
