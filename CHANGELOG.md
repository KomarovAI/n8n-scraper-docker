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
