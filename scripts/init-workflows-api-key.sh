#!/bin/bash
# Initialize n8n workflows using Official N8N API Key Authentication
# Official Method: https://docs.n8n.io/api/authentication/
# Uses X-N8N-API-KEY header (stateless, persistent, CI/CD-friendly)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🚀 n8n Workflow Initialization (Official API Key Method)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY}"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-workflows}"

if [ -z "$N8N_API_KEY" ]; then
  echo -e "${RED}❌ N8N_API_KEY not set!${NC}"
  echo ""
  echo "Create API key in n8n:"
  echo "  1. Open n8n UI → Settings → n8n API"
  echo "  2. Click 'Create an API key'"
  echo "  3. Label: 'CI/CD Pipeline'"
  echo "  4. Scopes: workflow:create, workflow:read, workflow:update"
  echo "  5. Export: export N8N_API_KEY='n8n_api_xxxxx'"
  exit 1
fi

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   API Key: ${N8N_API_KEY:0:15}... (${#N8N_API_KEY} chars)"
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

# ═══════════════════════════════════════════════════════════════
# STEP 1: IMPORT WORKFLOWS USING N8N PUBLIC API
# Official Endpoint: POST /api/v1/workflows
# Authentication: X-N8N-API-KEY header
# ═══════════════════════════════════════════════════════════════

echo "📦 Step 1: Importing workflows..."
echo "───────────────────────────────────────────────────────────────"

# Count workflows
WORKFLOW_COUNT=$(ls -1 "$WORKFLOWS_DIR"/*.json 2>/dev/null | wc -l)

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No workflow files found in $WORKFLOWS_DIR/${NC}"
  exit 1
fi

echo "Found $WORKFLOW_COUNT workflow file(s)"
echo ""

# Import workflows
IMPORTED=0
FAILED=0
WORKFLOW_IDS=()

for workflow_file in "$WORKFLOWS_DIR"/*.json; do
  WORKFLOW_NAME=$(basename "$workflow_file" .json)
  
  echo -n "[$((IMPORTED + FAILED + 1))/$WORKFLOW_COUNT] Importing $WORKFLOW_NAME ... "
  
  WORKFLOW_JSON=$(cat "$workflow_file")
  
  # Import via N8N Public API
  IMPORT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -X POST "${N8N_URL}/api/v1/workflows" \
    -d "$WORKFLOW_JSON" 2>&1)
  
  IMPORT_HTTP_CODE=$(echo "$IMPORT_RESPONSE" | tail -n1)
  IMPORT_BODY=$(echo "$IMPORT_RESPONSE" | sed '$d')
  
  if [ "$IMPORT_HTTP_CODE" -ne 200 ] && [ "$IMPORT_HTTP_CODE" -ne 201 ]; then
    echo -e "${RED}❌ Failed (HTTP $IMPORT_HTTP_CODE)${NC}"
    echo "   Response: ${IMPORT_BODY:0:150}..."
    FAILED=$((FAILED + 1))
    continue
  fi
  
  # Extract workflow ID
  WORKFLOW_ID=$(echo "$IMPORT_BODY" | grep -oP '"id":\s*"\K[^"]+' | head -1)
  
  if [ -z "$WORKFLOW_ID" ]; then
    echo -e "${RED}❌ Failed (no ID returned)${NC}"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  WORKFLOW_IDS+=("$WORKFLOW_ID")
  
  echo -e "${GREEN}✅ Imported (ID: $WORKFLOW_ID)${NC}"
  IMPORTED=$((IMPORTED + 1))
  
  sleep 1
done

echo ""
echo "Import summary:"
echo "  Imported: $IMPORTED"
echo "  Failed:   $FAILED"
echo ""

if [ "$IMPORTED" -eq 0 ]; then
  echo -e "${RED}❌ No workflows imported!${NC}"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════
# STEP 2: FORCE WEBHOOK REACTIVATION
# Critical: n8n v1.x doesn't register webhooks after import
# Solution: Deactivate + Reactivate via API
# Source: https://github.com/n8n-io/n8n/issues/14646
# ═══════════════════════════════════════════════════════════════

echo "🔄 Step 2: Force webhook reactivation..."
echo "───────────────────────────────────────────────────────────────"

REACTIVATED=0
REACT_FAILED=0

for WORKFLOW_ID in "${WORKFLOW_IDS[@]}"; do
  echo -n "   Reactivating workflow ID: $WORKFLOW_ID ... "
  
  # Deactivate first
  DEACTIVATE=$(curl -s -w "\n%{http_code}" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -X PATCH "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" \
    -d '{"active": false}' 2>&1)
  
  DEACT_CODE=$(echo "$DEACTIVATE" | tail -n1)
  
  sleep 2
  
  # Reactivate (triggers webhook registration)
  ACTIVATE=$(curl -s -w "\n%{http_code}" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -X PATCH "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" \
    -d '{"active": true}' 2>&1)
  
  ACT_CODE=$(echo "$ACTIVATE" | tail -n1)
  ACT_BODY=$(echo "$ACTIVATE" | sed '$d')
  
  if [ "$ACT_CODE" -eq 200 ] && echo "$ACT_BODY" | grep -qi '"active".*true'; then
    echo -e "${GREEN}✅${NC}"
    REACTIVATED=$((REACTIVATED + 1))
  else
    echo -e "${RED}❌ Failed (HTTP $ACT_CODE)${NC}"
    REACT_FAILED=$((REACT_FAILED + 1))
  fi
  
  sleep 2
done

echo ""
echo "Reactivation summary:"
echo "  Success: $REACTIVATED"
echo "  Failed:  $REACT_FAILED"
echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 3: WAIT FOR WEBHOOK REGISTRATION
# n8n needs time to register webhooks in routing table
# Source: Community best practices
# ═══════════════════════════════════════════════════════════════

echo "⏳ Step 3: Waiting for webhook registration..."
echo "───────────────────────────────────────────────────────────────"

WEBHOOK_WAIT=30
echo "Waiting ${WEBHOOK_WAIT} seconds for webhook initialization..."
sleep $WEBHOOK_WAIT

echo -e "${GREEN}✅ Webhook initialization window complete${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 4: VERIFICATION
# ═══════════════════════════════════════════════════════════════

echo "🔍 Step 4: Verifying active workflows..."
echo "───────────────────────────────────────────────────────────────"

VERIFY=$(curl -s \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "${N8N_URL}/api/v1/workflows" 2>&1)

ACTIVE_COUNT=$(echo "$VERIFY" | grep -o '"active":true' | wc -l)

if [ "$ACTIVE_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ Found $ACTIVE_COUNT active workflow(s)${NC}"
else
  echo -e "${YELLOW}⚠️  No active workflows found${NC}"
fi

echo ""

# Final summary
if [ "$FAILED" -eq 0 ] && [ "$REACT_FAILED" -eq 0 ]; then
  echo -e "${GREEN}🎉 Workflow initialization complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Run tests: bash scripts/test-n8n-workflows.sh"
  echo "  2. Check webhooks: curl -X POST http://localhost:5678/webhook/scrape -H 'Content-Type: application/json' -d '{\"url\":\"https://example.com\"}'"
  exit 0
else
  echo -e "${RED}⚠️  Some operations failed${NC}"
  echo "  Import failures: $FAILED"
  echo "  Reactivation failures: $REACT_FAILED"
  exit 1
fi
