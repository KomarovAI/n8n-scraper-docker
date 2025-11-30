# n8n Workflow Patterns

> **Purpose**: Reference guide for building production-ready n8n workflows.

---

## 🎯 Core Principles

### 1. Explicit Response Handling

**Always use dedicated `Respond to Webhook` node for webhook workflows.**

```json
{
  "name": "Respond to Webhook",
  "type": "n8n-nodes-base.respondToWebhook",
  "parameters": {
    "respondWith": "json",
    "responseBody": "={{ $json }}",
    "options": {
      "responseCode": "={{$json.success === true ? 200 : 400}}"
    }
  }
}
```

**Webhook configuration**:
```json
{
  "name": "Webhook",
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "responseMode": "responseNode",  // NOT "lastNode"!
    "httpMethod": "POST",
    "path": "api/endpoint"
  }
}
```

---

## 🛡️ Security Patterns

### SSRF Protection

**Always validate URLs in Input Validator node:**

```javascript
// SSRF Protection Pattern
const url = $json.url;
if (!url || !url.startsWith('http')) {
  throw new Error('Invalid URL');
}

// Block internal IPs
const blockedHosts = [
  'localhost', '127.0.0.1', '0.0.0.0',
  '169.254.169.254',  // AWS metadata
  'metadata.google.internal'  // GCP metadata
];

const urlObj = new URL(url);
if (blockedHosts.includes(urlObj.hostname)) {
  throw new Error('SSRF detected - blocked host');
}

// Check private IP ranges
if (/^(10|172\.16|192\.168)\./.test(urlObj.hostname)) {
  throw new Error('Private IP blocked');
}

return { json: { url, validated: true } };
```

---

## ⚠️ Error Handling Pattern

### Complete Error Flow

```
HTTP Request (continueOnFail: true)
    ↓
Check Success (IF node: statusCode == 200?)
    ├─ TRUE → Process Data
    └─ FALSE → Format Error
         ↓
    Both → Respond to Webhook
```

**IF Node Configuration**:
```json
{
  "name": "Check HTTP Success",
  "type": "n8n-nodes-base.if",
  "parameters": {
    "conditions": {
      "number": [
        {
          "value1": "={{$json.statusCode || 0}}",
          "operation": "equal",
          "value2": 200
        }
      ]
    }
  }
}
```

**HTTP Request Configuration**:
```json
{
  "name": "HTTP Request",
  "type": "n8n-nodes-base.httpRequest",
  "continueOnFail": true,  // ✅ Essential!
  "parameters": {
    "url": "={{$json.url}}",
    "options": {
      "timeout": 30000
    }
  }
}
```

**Error Formatter**:
```javascript
// Format Error Node
const url = $('Input Validator').item.json.url;
const requestId = $('Input Validator').item.json.requestId;
const statusCode = $input.item.json.statusCode || 0;

return {
  json: {
    success: false,
    url,
    requestId,
    timestamp: new Date().toISOString(),
    error: {
      type: 'HTTP_ERROR',
      status: statusCode,
      message: $input.item.json.statusMessage || 'Request failed'
    }
  }
};
```

---

## 📊 Data Access Patterns

### Correct Way to Access Node Data

```javascript
// ✅ CORRECT: Access current node input
const httpResponse = $input.item.json;
const html = httpResponse.body || '';  // With fallback
const statusCode = httpResponse.statusCode || 0;

// ✅ CORRECT: Access specific previous node
const url = $('Input Validator').item.json.url;
const requestId = $('Input Validator').item.json.requestId;

// ✅ CORRECT: Alternative syntax
const data = $node['Node Name'].json;

// ❌ WRONG: Direct property access
const html = $input.item.body;  // undefined!
const url = $input.item.json.url;  // May be undefined
```

### Defensive Programming

**Always use fallbacks:**
```javascript
const title = titleMatch ? titleMatch[1] : '';
const content = mainRegex.exec(html)?.[1] || '';
const length = content?.length || 0;
```

---

## 🔄 Rate Limiting Pattern

### Redis-Based Rate Limiter

```javascript
// Rate Limiter Node (before main logic)
const redis = require('redis');
const client = redis.createClient({ url: 'redis://redis:6379' });
await client.connect();

const ip = $json.headers['x-forwarded-for'] || 
           $json.headers['x-real-ip'] || 
           'unknown';
const key = `rate:${ip}`;
const count = await client.incr(key);

if (count === 1) {
  await client.expire(key, 60);  // 60-second window
}

if (count > 100) {  // 100 requests/min limit
  await client.disconnect();
  throw new Error('Rate limit exceeded: max 100 requests per minute');
}

await client.disconnect();
return { json: $json };
```

---

## 💾 Caching Pattern

### Redis Cache for Expensive Operations

**Check Cache Node**:
```json
{
  "name": "Check Cache",
  "type": "n8n-nodes-base.redis",
  "parameters": {
    "operation": "get",
    "key": "={{`scrape:${$json.url}`}}"
  }
}
```

**Cache Hit Decision**:
```json
{
  "name": "Cache Hit?",
  "type": "n8n-nodes-base.if",
  "parameters": {
    "conditions": {
      "string": [
        {
          "value1": "={{$json.value}}",
          "operation": "isNotEmpty"
        }
      ]
    }
  }
}
```

**Save to Cache**:
```json
{
  "name": "Save to Cache",
  "type": "n8n-nodes-base.redis",
  "parameters": {
    "operation": "set",
    "key": "={{`scrape:${$json.url}`}}",
    "value": "={{JSON.stringify($json.data)}}",
    "expire": true,
    "expireAfter": 3600  // 1 hour TTL
  }
}
```

---

## 🔁 Retry Pattern

### Exponential Backoff

```javascript
// Retry with Exponential Backoff
async function fetchWithRetry(url, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await fetch(url, {
        timeout: 30000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; n8n-scraper)'
        }
      });
      
      if (response.ok) {
        return await response.text();
      }
      
      // Retry on 5xx errors, not 4xx
      if (response.status >= 500 && attempt < maxRetries - 1) {
        const delay = 1000 * Math.pow(2, attempt);  // 1s, 2s, 4s
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      
      throw new Error(`HTTP ${response.status}`);
    } catch (error) {
      if (attempt === maxRetries - 1) {
        throw error;
      }
      const delay = 1000 * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

const html = await fetchWithRetry($json.url);
return { json: { html, url: $json.url } };
```

---

## 📦 Complete Workflow Template

### Production-Ready Webhook Workflow

```json
{
  "name": "Production Webhook Template",
  "meta": {
    "version": "1.0.0",
    "description": "Template for production webhooks",
    "dependencies": {
      "required": ["postgres", "redis"],
      "optional": ["prometheus"]
    }
  },
  "nodes": [
    {
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "responseMode": "responseNode",
        "httpMethod": "POST"
      }
    },
    {
      "name": "Input Validator",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "functionCode": "// SSRF + validation"
      }
    },
    {
      "name": "Rate Limiter",
      "type": "n8n-nodes-base.code"
    },
    {
      "name": "Check Cache",
      "type": "n8n-nodes-base.redis"
    },
    {
      "name": "Cache Hit?",
      "type": "n8n-nodes-base.if"
    },
    {
      "name": "Process Request",
      "type": "n8n-nodes-base.httpRequest",
      "continueOnFail": true
    },
    {
      "name": "Check Success",
      "type": "n8n-nodes-base.if"
    },
    {
      "name": "Process Data",
      "type": "n8n-nodes-base.code"
    },
    {
      "name": "Format Error",
      "type": "n8n-nodes-base.code"
    },
    {
      "name": "Save to Cache",
      "type": "n8n-nodes-base.redis"
    },
    {
      "name": "Store Result",
      "type": "n8n-nodes-base.postgres"
    },
    {
      "name": "Emit Metrics",
      "type": "n8n-nodes-base.httpRequest"
    },
    {
      "name": "Respond to Webhook",
      "type": "n8n-nodes-base.respondToWebhook"
    }
  ]
}
```

**Flow**:
```
Webhook → Validator → Rate Limiter → Check Cache
    ↓                                    ↓
Cache Miss                          Cache Hit
    ↓                                    ↓
Process Request → Check Success          ↓
    ├─ Success → Process Data             ↓
    └─ Failure → Format Error             ↓
         ↓                                    ↓
    Save to Cache                           ↓
         ↓                                    ↓
    Store Result                            ↓
         ↓                                    ↓
    Emit Metrics                            ↓
         └───────────────────────────────────┘
                  Respond to Webhook
```

---

## ✅ Pre-Deployment Checklist

### Before deploying workflow:

- [ ] ✅ Webhook uses `responseMode: "responseNode"`
- [ ] ✅ Explicit `Respond to Webhook` node present
- [ ] ✅ All external calls have `continueOnFail: true`
- [ ] ✅ Error handling implemented (IF nodes)
- [ ] ✅ SSRF protection in Input Validator
- [ ] ✅ Rate limiting added (if public endpoint)
- [ ] ✅ Data access uses correct patterns
- [ ] ✅ Fallbacks for all undefined values
- [ ] ✅ Version metadata added
- [ ] ✅ Dependencies documented
- [ ] ✅ Tested with invalid inputs
- [ ] ✅ Tested with network failures

---

## 📚 References

- [n8n Webhook Node Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)
- [Respond to Webhook Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.respondtowebhook/)
- [Error Handling Best Practices](https://community.n8n.io/t/catch-error-from-final-node-in-webhook-response/2650)
- Project AUDIT-REPORT.md (root cause analysis)

---

**Maintained by**: @KomarovAI  
**Last Updated**: 2025-11-30  
**Version**: 1.0
