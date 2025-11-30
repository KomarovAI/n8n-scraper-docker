# N8N API Key Setup Guide

## 🎯 Overview

This guide explains how to set up **N8N API Key authentication** for CI/CD pipelines.

**Why API Key?**
- ✅ **Official n8n method** (recommended)
- ✅ **Stateless** - no session expiry
- ✅ **Persistent** - single token for all operations
- ✅ **CI/CD-friendly** - works in any environment
- ✅ **Simpler** - no cookie management

**Official Documentation**: https://docs.n8n.io/api/authentication/

---

## 🔑 Step 1: Create N8N API Key

### **In n8n UI**

1. **Open n8n** in your browser:
   ```
   http://localhost:5678
   ```

2. **Navigate to Settings**:
   - Click your profile icon (top right)
   - Select **Settings**

3. **Go to n8n API section**:
   - In left sidebar: **Settings → n8n API**

4. **Create API Key**:
   - Click **"Create an API key"** button
   - **Label**: `CI/CD Pipeline` (or any descriptive name)
   - **Expiration**: `Never` (recommended for CI/CD)
   - **Scopes**: Select the following:
     - ☑️ `workflow:create`
     - ☑️ `workflow:read`
     - ☑️ `workflow:update`
     - ☑️ `workflow:delete` (optional)

5. **Copy API Key**:
   - ⚠️ **IMPORTANT**: Copy immediately - it won't be shown again!
   - Format: `n8n_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

## 🔐 Step 2: Add to GitHub Secrets

### **In GitHub Repository**

1. **Navigate to repository settings**:
   ```
   https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions
   ```

2. **Click "New repository secret"**

3. **Add N8N_API_KEY secret**:
   - **Name**: `N8N_API_KEY`
   - **Value**: Paste your API key (e.g., `n8n_api_xxxxx...`)
   - Click **"Add secret"**

4. **Verify secret is added**:
   - You should see `N8N_API_KEY` in the secrets list
   - Secret value will be hidden

---

## ⚙️ Step 3: Update CI Workflow (Already Done)

The GitHub Actions workflow `.github/workflows/2-n8n-validation.yaml` is already configured to use `N8N_API_KEY`:

```yaml
- name: Initialize workflows with N8N API Key
  env:
    N8N_URL: "http://localhost:5678"
    N8N_API_KEY: ${{ secrets.N8N_API_KEY }}
  run: bash scripts/init-workflows-api-key.sh
```

---

## 📦 Step 4: Test Locally (Optional)

### **Local Testing**

1. **Export API Key**:
   ```bash
   export N8N_API_KEY="n8n_api_xxxxxxxxxxxxxxxxxxxxxxxx"
   export N8N_URL="http://localhost:5678"
   export WORKFLOWS_DIR="workflows"
   ```

2. **Start n8n**:
   ```bash
   docker compose up -d n8n
   ```

3. **Run initialization script**:
   ```bash
   bash scripts/init-workflows-api-key.sh
   ```

4. **Expected output**:
   ```
   🚀 n8n Workflow Initialization (Official API Key Method)
   ═════════════════════════════════════════════════════════════
   
   📊 Configuration:
      n8n URL: http://localhost:5678
      API Key: n8n_api_xxxxx... (35 chars)
      Workflows Dir: workflows
   
   🔍 Checking n8n availability...
   ✅ n8n is accessible
   
   📦 Step 1: Importing workflows...
   [1/3] Importing workflow-scraper-main ... ✅ Imported (ID: abc123)
   [2/3] Importing workflow-scraper-enhanced ... ✅ Imported (ID: def456)
   [3/3] Importing control-panel ... ✅ Imported (ID: ghi789)
   
   🔄 Step 2: Force webhook reactivation...
   Reactivating workflow ID: abc123 ... ✅
   Reactivating workflow ID: def456 ... ✅
   Reactivating workflow ID: ghi789 ... ✅
   
   ⏳ Step 3: Waiting for webhook registration...
   ✅ Webhook initialization window complete
   
   🔍 Step 4: Verifying active workflows...
   ✅ Found 3 active workflow(s)
   
   🎉 Workflow initialization complete!
   ```

---

## 🔄 Migration from Cookie Auth

### **If you were using old method (N8N_USER + N8N_PASSWORD)**:

**1. Create N8N API Key** (see Step 1 above)

**2. Add to GitHub Secrets** (see Step 2 above)

**3. Remove old secrets** (optional cleanup):
   - You can safely delete:
     - `N8N_USER`
     - `N8N_PASSWORD`
   - These are no longer used

**4. Verify CI workflow**:
   - New workflow uses `init-workflows-api-key.sh`
   - No changes needed - already updated!

---

## 🛠️ Troubleshooting

### **Error: "N8N_API_KEY not set!"**

**Cause**: API key environment variable is missing

**Solution**:
```bash
# Local testing:
export N8N_API_KEY="your_api_key_here"

# GitHub Actions:
# Add N8N_API_KEY to repository secrets
```

---

### **Error: "HTTP 401 Unauthorized"**

**Cause**: Invalid or expired API key

**Solution**:
1. Generate new API key in n8n UI
2. Update GitHub secret `N8N_API_KEY`
3. Retry workflow

---

### **Error: "HTTP 403 Forbidden"**

**Cause**: API key doesn't have required scopes

**Solution**:
1. Delete old API key in n8n UI
2. Create new key with correct scopes:
   - `workflow:create`
   - `workflow:read`
   - `workflow:update`
3. Update GitHub secret

---

### **Error: "Workflow import failed (HTTP 400)"**

**Cause**: Invalid workflow JSON

**Solution**:
1. Validate workflow JSON:
   ```bash
   cat workflows/workflow-scraper-main.json | jq .
   ```
2. Check for syntax errors
3. Ensure workflow has valid structure

---

### **Webhooks not responding**

**Cause**: Webhook registration delay

**Solution**:
- Script already waits 30 seconds
- For manual testing, wait additional 30-60s
- Run diagnostic:
  ```bash
  bash scripts/debug-webhook-status.sh
  ```

---

## 📚 Additional Resources

### **Official Documentation**

- **n8n API Authentication**: https://docs.n8n.io/api/authentication/
- **n8n API Reference**: https://docs.n8n.io/api/api-reference/
- **n8n Workflows API**: https://docs.n8n.io/api/api-reference/#tag/Workflow

### **Related Guides**

- **Webhook Fix Documentation**: `scripts/README-WEBHOOK-FIX.md`
- **CI/CD Best Practices**: https://lumadock.com/blog/tutorials/n8n-cicd/

---

## ✅ Verification Checklist

- [ ] N8N API Key created in n8n UI
- [ ] API Key has correct scopes (workflow:create, workflow:read, workflow:update)
- [ ] `N8N_API_KEY` added to GitHub Secrets
- [ ] Local test successful (optional)
- [ ] CI workflow passes
- [ ] Webhooks responding correctly

---

## 💡 Best Practices

1. **Use descriptive labels** for API keys (e.g., "Production CI/CD", "Development")
2. **Set expiration** to "Never" for CI/CD keys
3. **Rotate keys periodically** (e.g., every 6 months)
4. **Use separate keys** for different environments (dev, staging, prod)
5. **Never commit** API keys to repository
6. **Monitor usage** in n8n API logs

---

**✅ You're all set!** Your CI/CD pipeline now uses the official n8n API authentication method.
