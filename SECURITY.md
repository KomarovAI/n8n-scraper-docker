# Security Policy

## 🔒 Supported Versions

| Version | Supported          | Notes |
|---------|--------------------|-------|
| 3.0.x   | ✅ Yes            | Current production |
| 2.x.x   | ⚠️ Limited support | Security patches only |
| < 2.0   | ❌ No              | End of life |

---

## 🚨 Critical Security Alerts

### CVE-2025-62725: Docker Compose Path Traversal

**Severity**: HIGH (CVSS 8.9)  
**Component**: Docker Compose  
**Affected Versions**: < v2.40.2  
**Status**: ⚠️ **MITIGATION REQUIRED**

#### Impact
- **Path Traversal** vulnerability in Docker Compose OCI artifacts
- Allows attackers to overwrite arbitrary files via malicious compose files
- Production deployments at risk if using Docker Compose < v2.40.2

#### Mitigation

**REQUIRED ACTION**: Update Docker Compose to v2.40.2 or higher

```bash
# 1. Check current version
docker-compose --version
# If < 2.40.2, proceed with update

# 2. Download patched version
sudo curl -SL https://github.com/docker/compose/releases/download/v2.40.2/docker-compose-linux-x86_64 \
  -o /usr/local/bin/docker-compose

# 3. Set permissions
sudo chmod +x /usr/local/bin/docker-compose

# 4. Verify update
docker-compose --version
# Should show: Docker Compose version v2.40.2 or higher

# 5. Restart services
cd /path/to/n8n-scraper-docker
docker-compose down
docker-compose up -d
```

**References**:
- [CVE-2025-62725 Details](https://nvd.nist.gov/vuln/detail/CVE-2025-62725)
- [Docker Compose Release Notes](https://github.com/docker/compose/releases/tag/v2.40.2)

---

## 🛡️ Security Checklist (Production)

### Pre-Deployment

- [ ] **Update Docker Compose** to v2.40.2+ (CVE-2025-62725)
- [ ] **Generate strong passwords** (20+ chars): `openssl rand -base64 24`
- [ ] **Set all required secrets** in `.env` file
- [ ] **Never commit** `.env` to version control (already in .gitignore)
- [ ] **Enable firewall** (only ports 22, 5678, 3000, 9090)
- [ ] **Configure SSL/TLS** with reverse proxy (nginx/Caddy)
- [ ] **Enable Dependabot** for automated dependency updates
- [ ] **Set up automated backups** (daily PostgreSQL + volumes)
- [ ] **Test disaster recovery** procedure (quarterly)

### Runtime Security

```bash
# 1. Verify no secrets in logs
docker-compose logs | grep -i "password\|token\|secret" && echo "❌ Secrets exposed!" || echo "✅ OK"

# 2. Check for vulnerable images
docker scout cves n8n-enhanced:latest

# 3. Verify service health
curl -sf http://localhost:5678/healthz || echo "❌ n8n unhealthy"
curl -sf http://localhost:9090/-/healthy || echo "❌ Prometheus unhealthy"

# 4. Check PostgreSQL connections
docker-compose exec postgres psql -U n8n_user -c "SELECT COUNT(*) FROM pg_stat_activity;"

# 5. Verify Redis auth
docker-compose exec redis redis-cli -a "${REDIS_PASSWORD}" ping || echo "❌ Redis auth failed"
```

### Firewall Configuration (Production)

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 5678/tcp  # n8n (if no reverse proxy)
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw enable

# Verify
sudo ufw status
```

### Reverse Proxy (Recommended)

**nginx example** (`/etc/nginx/sites-available/n8n`):

```nginx
server {
    listen 443 ssl http2;
    server_name n8n.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/n8n.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/n8n.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 🐛 Vulnerability Reporting

### Reporting a Vulnerability

If you discover a security vulnerability, please follow responsible disclosure:

1. **Do NOT** create a public GitHub issue
2. **Email**: artur.komarovv@gmail.com
3. **Subject**: `[SECURITY] n8n-scraper-docker vulnerability`
4. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Fix Timeline**: Critical (7 days), High (14 days), Medium (30 days)
- **Disclosure**: After fix is deployed and users notified

### Security Updates

- Critical security patches are released immediately
- Users are notified via GitHub Security Advisories
- Update instructions provided in release notes

---

## 📝 Password Policy

### Requirements

- **Minimum length**: 20 characters
- **Complexity**: Mix of uppercase, lowercase, numbers, symbols
- **Rotation**: Every 90 days for production
- **Storage**: Never commit to version control

### Generation

```bash
# Generate secure password (recommended)
openssl rand -base64 24

# Or use pwgen
pwgen -s 24 1
```

### Secrets in `.env`

```bash
# Required secrets (20+ chars each)
POSTGRES_PASSWORD=<generate_unique>
REDIS_PASSWORD=<generate_unique>
N8N_PASSWORD=<generate_unique>
TOR_CONTROL_PASSWORD=<generate_unique>
GRAFANA_PASSWORD=<generate_unique>

# Optional API Keys (add @ai-ignore for AI tools)
FIRECRAWL_API_KEY=fc-xxx  # @ai-ignore
JINA_API_KEY=jina-xxx      # @ai-ignore
```

---

## 📋 Compliance

### SOC 2 Type II

- ✅ Automated backups (daily)
- ✅ Access controls (passwords, firewall)
- ✅ Monitoring (Prometheus + Grafana)
- ✅ Audit logs (Docker logs, PostgreSQL logs)
- ✅ Incident response (disaster recovery plan)

### GDPR

- ✅ Data encryption at rest (PostgreSQL)
- ✅ Data encryption in transit (SSL/TLS via reverse proxy)
- ✅ Right to erasure (PostgreSQL delete queries)
- ✅ Data portability (pg_dump exports)
- ✅ Breach notification (within 72 hours)

---

## 🔍 Security Scanning

### Docker Images

```bash
# Scan for vulnerabilities
docker scout cves n8n-enhanced:latest

# Generate SBOM (Software Bill of Materials)
docker scout sbom n8n-enhanced:latest
```

### Dependencies

```bash
# Python dependencies (ml-service)
cd ml && pip-audit

# GitHub Actions
# Dependabot automatically scans (see .github/dependabot.yml)
```

### Secrets Scanning (CI/CD)

```bash
# TruffleHog (already in CI pipeline)
docker run --rm -v "$(pwd)":/path trufflesecurity/trufflehog:latest \
  filesystem /path --only-verified --fail
```

---

## 📚 Resources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [n8n Security Best Practices](https://docs.n8n.io/hosting/security/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)

---

**Last Updated**: 2025-11-28  
**Maintainer**: Security Team  
**Review Cycle**: Quarterly
