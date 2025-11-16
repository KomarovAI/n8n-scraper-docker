# Security Best Practices

## Overview

This document outlines security measures implemented in the N8N scraper workflow and best practices for operators.

## Implemented Security Controls

### 1. Input Validation (OWASP A03:2021)

**Threat**: Malicious input can lead to SSRF, command injection, or data exfiltration.

**Controls**:
- Pydantic schema validation with strict typing
- URL scheme whitelist (http/https only)
- Hostname/IP blacklist (localhost, private IPs, cloud metadata)
- CSS selector sanitization (regex validation)
- Batch size limits (max 100 URLs)

**Code Location**: `scripts/validate_input.py`, `scripts/validate_input.js`

### 2. SSRF Protection (OWASP A10:2021)

**Threat**: Attackers can probe internal network or access cloud metadata.

**Blocked Targets**:
```
# IPv4 loopback
127.0.0.1, localhost, 0.0.0.0

# IPv6 loopback
::1, 0000:0000:0000:0000:0000:0000:0000:0001

# Private networks (RFC1918)
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16

# IPv6 private
fc00::/7 (ULA)
fe80::/10 (link-local)

# Cloud metadata
169.254.169.254 (AWS)
metadata.google.internal (GCP)
metadata.azure.com (Azure)
```

### 3. GitHub Actions Security

**Threats**: Script injection, token theft, supply chain attacks.

**Controls**:
- SHA-pinned action versions (prevents tag mutation)
- Minimal permissions (principle of least privilege)
- Input validation before use (no direct interpolation)
- Artifact integrity verification
- Secret masking in logs

**Example**:
```yaml
permissions:
  contents: read
  actions: read  # No write access
  
steps:
  - name: Validate input
    env:
      URLS_JSON: ${{ inputs.urls }}  # Safe: env var
    run: python validate_input.py
    # Never: run: echo "${{ inputs.urls }}" | script.py
```

### 4. Network Isolation

**Threat**: Lateral movement, data exfiltration.

**Controls**:
- NetworkPolicy restricts ingress to ingress-nginx only
- NetworkPolicy restricts egress to:
  - DNS (kube-system)
  - PostgreSQL (same namespace)
  - Redis (same namespace)
  - Whitelisted external domains (via Calico/Cilium)
  
**Egress Whitelist**:
```yaml
# Required domains
- github.com (for API)
- api.firecrawl.dev (fallback scraper)
- objects.githubusercontent.com (artifacts)
```

### 5. Secrets Management

**Threat**: Secret exposure, unauthorized access.

**Current Implementation**:
- Kubernetes Secrets with RBAC
- Secrets injected as environment variables
- No secrets in logs (masked)

**Recommendations for Production**:
- External Secrets Operator + HashiCorp Vault
- Automatic secret rotation (90 days)
- Audit logging for secret access

### 6. Rate Limiting

**Threat**: DoS, quota exhaustion, IP blocking.

**Controls**:
- Redis-based token bucket per IP
- Limits: 100 URLs/minute, 1000 URLs/hour
- GitHub Actions quota monitoring

**Configuration**:
```python
# In N8N workflow
rate_limit = redis.RateLimiter(
    key=f"scraper:{client_ip}",
    max_requests=100,
    window_seconds=60
)
```

## Threat Model

### Attack Scenarios

#### Scenario 1: SSRF to AWS Metadata

**Attack**: 
```json
{"url": "http://169.254.169.254/latest/meta-data/iam/security-credentials/"}
```

**Mitigation**: Blocked by `validate_input.py` line 47

**Severity**: CRITICAL (10.0 CVSS)

#### Scenario 2: Script Injection via GitHub Actions

**Attack**:
```yaml
on:
  repository_dispatch:
jobs:
  run:
    run: echo "${{ github.event.client_payload.urls }}"  # Vulnerable
```

**Mitigation**: Use environment variables, validate before use

**Severity**: CRITICAL (9.8 CVSS)

#### Scenario 3: Denial of Service

**Attack**: Send 10,000 URLs in single batch

**Mitigation**: Batch size limited to 100 in `validate_input.py`

**Severity**: MEDIUM (5.3 CVSS)

## Security Checklist for Operators

### Pre-Deployment

- [ ] Generate strong passwords (min 32 chars, random)
- [ ] Create GitHub PAT with minimal scopes (`repo`, `actions`)
- [ ] Review NetworkPolicy egress whitelist
- [ ] Enable Pod Security Standards (restricted)
- [ ] Configure TLS for ingress (Let's Encrypt)
- [ ] Set up secret encryption at rest (if using etcd)

### Post-Deployment

- [ ] Test SSRF protection with blocked IPs
- [ ] Verify rate limiting works
- [ ] Check Prometheus alerts are firing
- [ ] Review audit logs for suspicious activity
- [ ] Test disaster recovery procedures

### Ongoing Operations

- [ ] Rotate secrets every 90 days
- [ ] Update dependencies monthly (security patches)
- [ ] Review GitHub Actions logs weekly
- [ ] Monitor rate limit quotas
- [ ] Backup PostgreSQL daily

## Incident Response

### If SSRF is Detected

1. **Immediate**: Block source IP in Ingress
2. **15 min**: Review logs for data exfiltration
3. **1 hour**: Rotate all secrets
4. **24 hours**: Conduct forensic analysis
5. **7 days**: Update validation rules if bypass found

### If Token is Compromised

1. **Immediate**: Revoke GitHub PAT
2. **15 min**: Generate new PAT, update secret
3. **1 hour**: Review API call logs
4. **24 hours**: Check for unauthorized workflow runs
5. **7 days**: Enable GitHub Advanced Security

### If Pod is Compromised

1. **Immediate**: Delete pod, scale to 0
2. **15 min**: Isolate with NetworkPolicy
3. **1 hour**: Analyze container image for backdoors
4. **24 hours**: Restore from known-good image
5. **7 days**: Enable runtime security (Falco)

## Compliance

### GDPR Considerations

- Scraped data may contain PII
- Implement data retention policies (default: 90 days)
- Allow data deletion on request
- Log all access to scraped data

### SOC 2 Controls

- CC6.1: Logical access controls (RBAC, NetworkPolicy)
- CC6.6: Vulnerability management (Trivy, CodeQL)
- CC6.7: Encryption (TLS, secrets)
- CC7.2: Security monitoring (Prometheus alerts)

## Vulnerability Disclosure

If you discover a security vulnerability:

1. **Do NOT** open a public GitHub issue
2. Email: security@your-domain.com
3. Include: Description, steps to reproduce, impact
4. Expected response: 48 hours acknowledgment, 30 days fix

## References

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [CWE-918: SSRF](https://cwe.mitre.org/data/definitions/918.html)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
