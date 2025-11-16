## [2.1.0] - 2025-11-17
### Security
- **CRITICAL**: Updated playwright 1.40.0 → 1.48.0 (10+ months of security patches)
- **CRITICAL**: Updated requests 2.31.0 → 2.32.3 (fixes CVE-2024-35195 - HTTP Request Smuggling)
- **HIGH**: Updated selenium 4.15.2 → 4.27.1 (anti-bot bypass improvements)
- Updated puppeteer 22.0.0 → 23.9.0 (latest stable with security fixes)
- Updated undetected-chromedriver 3.5.4 → 3.5.5 (stability improvements)

### Added
- requirements-lock.txt for reproducible builds and security auditing
- Pre-commit hooks with Husky and lint-staged
- Dependency hash verification in CI/CD
- codecov integration for coverage tracking
- Dependency Review Action for PRs

### Changed
- Fixed CI/CD dependency paths (scripts/requirements.txt → requirements.txt)
- Improved pip cache strategy in GitHub Actions
- Updated all Node.js dependencies to latest versions:
  - jest 29.7.0 → 30.0.4
  - eslint 8.54.0 → 9.17.0
  - prettier 3.1.0 → 3.4.2
  - winston 3.11.0 → 3.17.0
  - ioredis 5.3.2 → 5.4.2
- pytest-asyncio 0.21.1 → 1.3.0 (Python 3.13 support)
- tenacity 8.2.3 → 9.1.2 (bug fixes and Python 3.13 support)

### Fixed
- CI workflow failing due to non-existent scripts/requirements.txt path
- Missing requirements-lock.txt causing non-reproducible builds
- Trivy action pinned to specific version (0.33.1) instead of @master

---

## [2.0.0] - 2025-11-16
### Added
- .gitignore to protect .env/credentials
- SECURITY.md with responsible vulnerability reporting
- Dependabot config for automated npm/pip/docker/actions updates
- Trivy, npm audit, pip-audit, GitLeaks security scanning in CI/CD
- ESLint and Prettier config, lint/format scripts in package.json
- Automated PostgreSQL and Redis backup scripts with S3 retention, 30-day cleanup
- Comprehensive .env.example with strong password requirements, rotation guidelines
- Major README security updates, production instructions

### Changed
- All passwords removed from docker-compose.yml, replaced with ${VAR:?} syntax
- TOR Control Port now always requires auth (TOR_CONTROL_PASSWORD)
- Healthchecks now mandatory for all services
- Service dependencies use healthcheck condition
- axios updated to 1.7.0+ (fix CVE-2023-45857)
- HPA minReplicas set to 3 to avoid PDB deadlock (audit)
- All npm, pip, docker dependencies reviewed for cvss>=7 issues

### Fixed
- Path traversal risk (CVE-2025-62725) - requires user to update Docker Compose to v2.40.2+
- Weak environment example passwords
- Several deprecated config/usage patterns warned in logs