#!/bin/bash
# Initialize n8n workflows with forced webhook reactivation
# Fixes n8n v1.x webhook registration issue after import
# Source: https://github.com/n8n-io/n8n/issues/14646

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🚀 n8n Workflow Initialization with Webhook Reactivation"
echo "═══════════════════════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin@example.com}"
N8N_PASSWORD="${N8N_PASSWORD}"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-workflows}"
COOKIE_FILE="/tmp/n8n-cookie.txt"

if [ -z "$N8N_PASSWORD" ] || [ -z "$N8N_USER" ]; then
  echo -e "${RED}❌ N8N_USER or N8N_PASSWORD not set!${NC}"
  exit 1
fi

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   n8n User: $N8N_USER"
echo "   Workflows Dir: $WORKFLOWS_DIR"
echo ""

# Check n8n availability
echo "🔍 Checking n8n availability..."
MAX_WAIT=60
WAIT_INTERVAL=5

for ((i=1; i<=MAX_WAIT/WAIT_INTERVAL; i++)); do
  if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ n8n is accessible${NC}"
    break
  fi
  
  if [ $i -eq $((MAX_WAIT/WAIT_INTERVAL)) ]; then
    echo -e "${RED}❌ n8n not accessible after ${MAX_WAIT}s${NC}"
    exit 1
  fi
  
  echo "   Waiting for n8n... ($((i * WAIT_INTERVAL))s/${MAX_WAIT}s)"
  sleep $WAIT_INTERVAL
done

echo ""

# ═══════════════════════════════════════════════════════
# STEP 1: IMPORT WORKFLOWS USING EXISTING SCRIPT
# ═══════════════════════════════════════════════════════

echo "📦 Step 1: Importing workflows..."
echo "──────────────────────────────────────────"

# Call existing import script
if [ -f "scripts/import-n8n-workflows.sh" ]; then
  bash scripts/import-n8n-workflows.sh
else
  echo -e "${RED}❌ import-n8n-workflows.sh not found!${NC}"
  exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════
# STEP 2: FORCE WEBHOOK REACTIVATION
# Critical: n8n v1.x doesn't register webhooks after import
# Solution: Deactivate + Reactivate via API
# Source: https://github.com/n8n-io/n8n/issues/14646
# ═══════════════════════════════════════════════════════

echo "🔄 Step 2: Force webhook reactivation..."
echo "──────────────────────────────────────────"

# Get authentication cookie
echo "🔐 Authenticating..."

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_FILE" \
  -X POST "${N8N_URL}/rest/login" \
  -d "{
    \"email\": \"${N8N_USER}\",
    \"password\": \"${N8N_PASSWORD}\"
  }" 2>&1)

LOGIN_HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)

if [ "$LOGIN_HTTP_CODE" -ne 200 ]; then
  echo -e "${RED}❌ Login failed (HTTP $LOGIN_HTTP_CODE)${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Authenticated${NC}"
echo ""

# Get all workflows
echo "📋 Fetching workflow list..."

WORKFLOWS=$(curl -s -b "$COOKIE_FILE" "${N8N_URL}/rest/workflows" 2>&1)

WORKFLOW_COUNT=$(echo "$WORKFLOWS" | grep -o '"id"' | wc -l)

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No workflows found!${NC}"
  exit 1
fi

echo "Found $WORKFLOW_COUNT workflow(s)"
echo ""

# Extract workflow IDs and reactivate each
REACTIVATED=0
FAILED=0

echo "🔄 Reactivating workflows for webhook registration..."

# Extract IDs using grep (more portable than jq)
WORKFLOW_IDS=$(echo "$WORKFLOWS" | grep -oP '"id":"\K[^"]+' || echo "")

if [ -z "$WORKFLOW_IDS" ]; then
  echo -e "${RED}❌ Could not extract workflow IDs${NC}"
  exit 1
fi

while IFS= read -r WORKFLOW_ID; do
  [ -z "$WORKFLOW_ID" ] && continue
  
  WORKFLOW_NAME=$(echo "$WORKFLOWS" | grep -A5 "\"id\":\"$WORKFLOW_ID\"" | grep -oP '"name":"\K[^"]+' | head -1)
  
  echo -n "   Reactivating: $WORKFLOW_NAME (ID: $WORKFLOW_ID) ... "
  
  # Deactivate first
  DEACTIVATE=$(curl -s -w "\n%{http_code}" \
    -b "$COOKIE_FILE" \
    -H "Content-Type: application/json" \
    -X PATCH "${N8N_URL}/rest/workflows/${WORKFLOW_ID}" \
    -d '{"active": false}' 2>&1)
  
  DEACT_CODE=$(echo "$DEACTIVATE" | tail -n1)
  
  sleep 2
  
  # Reactivate (triggers webhook registration)
  ACTIVATE=$(curl -s -w "\n%{http_code}" \
    -b "$COOKIE_FILE" \
    -H "Content-Type: application/json" \
    -X PATCH "${N8N_URL}/rest/workflows/${WORKFLOW_ID}" \
    -d '{"active": true}' 2>&1)
  
  ACT_CODE=$(echo "$ACTIVATE" | tail -n1)
  ACT_BODY=$(echo "$ACTIVATE" | sed '$d')
  
  if [ "$ACT_CODE" -eq 200 ] && echo "$ACT_BODY" | grep -qi '"active".*true'; then
    echo -e "${GREEN}✅${NC}"
    REACTIVATED=$((REACTIVATED + 1))
  else
    echo -e "${RED}❌ Failed (HTTP $ACT_CODE)${NC}"
    FAILED=$((FAILED + 1))
  fi
  
  sleep 2
done <<< "$WORKFLOW_IDS"

echo ""
echo "Reactivation summary:"
echo "  Success: $REACTIVATED"
echo "  Failed:  $FAILED"
echo ""

# ═══════════════════════════════════════════════════════
# STEP 3: WAIT FOR WEBHOOK REGISTRATION
# n8n needs time to register webhooks in routing table
# Source: Community best practices
# ═══════════════════════════════════════════════════════

echo "⏳ Step 3: Waiting for webhook registration..."
echo "──────────────────────────────────────────"

WEBHOOK_WAIT=30
echo "Waiting ${WEBHOOK_WAIT} seconds for webhook initialization..."
sleep $WEBHOOK_WAIT

echo -e "${GREEN}✅ Webhook initialization window complete${NC}"
echo ""

# ═══════════════════════════════════════════════════════
# STEP 4: VERIFICATION
# ═══════════════════════════════════════════════════════

echo "🔍 Step 4: Verifying active webhooks..."
echo "──────────────────────────────────────────"

VERIFY=$(curl -s -b "$COOKIE_FILE" "${N8N_URL}/rest/workflows" 2>&1)
ACTIVE_COUNT=$(echo "$VERIFY" | grep -o '"active":true' | wc -l)

if [ "$ACTIVE_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ Found $ACTIVE_COUNT active workflow(s)${NC}"
else
  echo -e "${YELLOW}⚠️  No active workflows found${NC}"
fi

echo ""

# Cleanup
rm -f "$COOKIE_FILE"

if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}🎉 Workflow initialization complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Run tests: bash scripts/test-n8n-workflows.sh"
  echo "  2. Check webhooks: curl -X POST http://localhost:5678/webhook/scrape -H 'Content-Type: application/json' -d '{\"url\":\"https://example.com\"}'"
  exit 0
else
  echo -e "${RED}⚠️  Some workflows failed to reactivate${NC}"
  exit 1
fi
