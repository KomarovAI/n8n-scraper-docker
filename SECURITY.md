# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          | End of Life |
| ------- | ------------------ | ----------- |
| 2.x     | :white_check_mark: | -           |
| 1.x     | :x:                | 2025-12-31  |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow our responsible disclosure process:

### 🔒 Private Disclosure (Preferred)

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report via:

1. **GitHub Security Advisories** (Recommended)
   - Go to: https://github.com/KomarovAI/n8n-scraper-workflow/security/advisories
   - Click "Report a vulnerability"
   - Provide detailed information (see template below)

2. **Email** (Alternative)
   - Send encrypted email to: artur.komarovv@gmail.com
   - Subject: `[SECURITY] n8n-scraper-workflow vulnerability`
   - PGP Key: Available on request

### 📋 Vulnerability Report Template

Please include:

```markdown
**Summary**: Brief description of the vulnerability

**Severity**: Critical / High / Medium / Low

**Component**: Which part of the system is affected (e.g., Docker Compose, Puppeteer scraper, TOR proxy)

**Description**: Detailed explanation of the vulnerability

**Steps to Reproduce**:
1. Step 1
2. Step 2
3. ...

**Impact**: What can an attacker achieve?

**Affected Versions**: Which versions are vulnerable?

**Suggested Fix**: (Optional) Your recommendation for fixing the issue

**Additional Context**: Logs, screenshots, PoC code
```

### ⏱️ Response Timeline

- **Initial Response**: Within 48 hours
- **Triage**: Within 7 days
- **Fix Development**: Depends on severity
  - Critical: 1-3 days
  - High: 7-14 days
  - Medium: 14-30 days
  - Low: 30-90 days
- **Public Disclosure**: After fix is released + 7 days grace period

### 🏆 Recognition

Security researchers who responsibly disclose vulnerabilities will be:

1. Acknowledged in the CHANGELOG (unless you prefer to remain anonymous)
2. Listed in our Hall of Fame (SECURITY.md)
3. Eligible for a contribution credit

## Security Best Practices for Users

### 🔐 Credentials Management

- ✅ **DO**: Use `.env` file with strong passwords (20+ characters)
- ✅ **DO**: Rotate passwords every 90 days
- ✅ **DO**: Use different passwords for each service
- ❌ **DON'T**: Commit `.env` to Git (already in `.gitignore`)
- ❌ **DON'T**: Share credentials in public channels

Generate strong passwords:
```bash
# Generate 32-character password
openssl rand -base64 32

# Alternative
pwgen -s 32 1
```

### 🐳 Docker Security

- ✅ Update Docker Compose to **v2.40.2+** (fixes CVE-2025-62725)
- ✅ Run containers as non-root user (configured in our docker-compose.yml)
- ✅ Use Docker secrets for production:
  ```bash
  echo "my_db_password" | docker secret create postgres_password -
  ```
- ✅ Enable Docker Content Trust: `export DOCKER_CONTENT_TRUST=1`

### 🔒 Network Security

- ✅ Use TOR Control Port authentication (set `TOR_CONTROL_PASSWORD`)
- ✅ Restrict Redis access with password (`REDIS_PASSWORD`)
- ✅ Enable PostgreSQL SSL in production
- ✅ Use Kubernetes NetworkPolicy for egress filtering (see `k8s/networkpolicy.yaml`)

### 📦 Dependency Security

- ✅ Enable Dependabot alerts (configured in `.github/dependabot.yml`)
- ✅ Run `npm audit` and `pip-audit` regularly
- ✅ Update dependencies monthly
- ✅ Use SHA pinning for GitHub Actions

### 🔄 Backup & Recovery

- ✅ Enable automated backups (PostgreSQL, Redis)
- ✅ Test backup restoration monthly
- ✅ Store backups in encrypted S3 buckets
- ✅ Keep backups for 30 days minimum

## Known Security Considerations

### Web Scraping Legal Compliance

⚠️ **DISCLAIMER**: This tool is for educational and authorized scraping only.

- **DO**: Respect `robots.txt`
- **DO**: Comply with website Terms of Service
- **DO**: Use rate limiting to avoid DDoS
- **DON'T**: Scrape copyrighted content without permission
- **DON'T**: Bypass authentication without authorization

### TOR Network Usage

⚠️ TOR provides anonymity but is not a silver bullet:

- TOR exit nodes can be compromised
- HTTPS is still required for end-to-end encryption
- Some websites block TOR exit IPs
- Clearnet + TOR combination can leak identity

### Rate Limiting

Our adaptive rate limiter protects against:
- ✅ Accidental DDoS of target websites
- ✅ IP bans from excessive requests
- ✅ Resource exhaustion on our infrastructure

Default: 5 req/sec, adaptive up to 10 req/sec

## Security Hall of Fame

_Thank you to the following security researchers:_

<!-- Add researchers here after disclosure -->

## Security Audits

- **Latest Audit**: 2025-11-16
- **Auditor**: Internal security review
- **Findings**: 18 issues identified (1 Critical, 4 High, 7 Medium, 6 Low)
- **Status**: Remediation in progress

## Compliance

### GDPR Compliance

- Data minimization: We only scrape publicly available data
- Right to erasure: `DELETE FROM scraped_data WHERE url = ?`
- Data portability: Export via PostgreSQL `COPY TO CSV`

### OWASP Top 10 (2021)

| Risk                          | Mitigation                              |
|-------------------------------|-----------------------------------------|
| A01 Broken Access Control     | ✅ Header Auth, N8N Basic Auth         |
| A02 Cryptographic Failures    | ✅ TLS/HTTPS, .env encryption          |
| A03 Injection                 | ✅ Pydantic validation, SQL params     |
| A04 Insecure Design           | ✅ Defense in depth, rate limiting     |
| A05 Security Misconfiguration | ✅ Security headers, no debug in prod  |
| A06 Vulnerable Components     | ✅ Dependabot, npm audit, pip-audit    |
| A07 ID & Auth Failures        | ✅ Strong passwords, 2FA (recommended) |
| A08 Software & Data Integrity | ✅ SHA pinning, signed commits         |
| A09 Logging & Monitoring      | ✅ Prometheus, Grafana, Winston        |
| A10 SSRF                      | ✅ IPv4/IPv6 filtering, metadata block |

## Contact

For non-security issues, please use:
- GitHub Issues: https://github.com/KomarovAI/n8n-scraper-workflow/issues
- Discussions: https://github.com/KomarovAI/n8n-scraper-workflow/discussions

For security vulnerabilities, **always** use private disclosure channels above.

---

**Last Updated**: 2025-11-16  
**Version**: 2.0.0  
**Maintainer**: KomarovAI
