#!/bin/bash
# Import n8n workflows via API and activate them
# Uses Basic Authentication (compatible with N8N_BASIC_AUTH_ACTIVE=true)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📦 n8n Workflow Import & Activation"
echo "═══════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin@example.com}"
N8N_PASSWORD="${N8N_PASSWORD}"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-workflows}"

if [ -z "$N8N_PASSWORD" ] || [ -z "$N8N_USER" ]; then
  echo -e "${RED}❌ N8N_USER or N8N_PASSWORD not set!${NC}"
  exit 1
fi

if [ ${#N8N_PASSWORD} -lt 8 ]; then
  echo -e "${RED}❌ Password too short! Minimum 8 characters required.${NC}"
  exit 1
fi

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   n8n User: $N8N_USER"
echo "   Password length: ${#N8N_PASSWORD} chars"
echo ""

# Check n8n availability
echo "🔍 Checking n8n availability..."
if ! curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
  echo -e "${RED}❌ n8n is not accessible at $N8N_URL${NC}"
  exit 1
fi
echo -e "${GREEN}✅ n8n is accessible${NC}"
echo ""

# Generate Basic Auth header
echo "🔐 Setting up Basic Authentication..."
BASIC_AUTH=$(echo -n "${N8N_USER}:${N8N_PASSWORD}" | base64)
AUTH_HEADER="Authorization: Basic ${BASIC_AUTH}"
echo -e "${GREEN}✅ Basic Auth ready${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# Test credentials using CORRECT endpoint
# /rest/me - Internal API endpoint for Basic Auth
# /api/v1/me - Public API endpoint requiring API key (WRONG!)
# ═══════════════════════════════════════════════════════════════

echo "🔍 Testing credentials via /rest/me..."
ME_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "${AUTH_HEADER}" \
  "${N8N_URL}/rest/me" 2>&1)

ME_HTTP_CODE=$(echo "$ME_RESPONSE" | tail -n1)
ME_BODY=$(echo "$ME_RESPONSE" | sed '$d')

if [ "$ME_HTTP_CODE" -eq 200 ]; then
  echo -e "${GREEN}✅ Credentials valid, auth ready${NC}"
  echo ""
elif [ "$ME_HTTP_CODE" -eq 401 ]; then
  echo -e "${YELLOW}⚠️  401 Unauthorized - owner exists with different password${NC}"
  echo -e "${YELLOW}⚠️  This should not happen in CI (clean environment)${NC}"
  echo -e "${RED}❌ Manual intervention required: Update GitHub Secrets${NC}"
  exit 1
elif [ "$ME_HTTP_CODE" -eq 404 ]; then
  echo -e "${YELLOW}⚠️  Owner not created yet${NC}"
  echo ""
  
  # Create owner
  echo "🔧 Creating owner account..."
  SETUP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -X POST "${N8N_URL}/rest/owner/setup" \
    -d "{
      \"email\": \"${N8N_USER}\",
      \"password\": \"${N8N_PASSWORD}\",
      \"firstName\": \"CI\",
      \"lastName\": \"User\"
    }" 2>&1)
  
  SETUP_HTTP_CODE=$(echo "$SETUP_RESPONSE" | tail -n1)
  SETUP_BODY=$(echo "$SETUP_RESPONSE" | sed '$d')
  
  if [ "$SETUP_HTTP_CODE" -eq 200 ] || [ "$SETUP_HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✅ Owner created successfully${NC}"
    echo ""
    
    # Small delay for auth middleware to stabilize (empirically 3-5s is enough)
    echo "⏳ Waiting 5s for auth stabilization..."
    sleep 5
    echo -e "${GREEN}✅ Ready to import workflows${NC}"
    echo ""
  else
    echo -e "${RED}❌ Failed to create owner (HTTP $SETUP_HTTP_CODE)${NC}"
    echo "Response: $SETUP_BODY"
    exit 1
  fi
else
  echo -e "${RED}❌ Unexpected response from /rest/me (HTTP $ME_HTTP_CODE)${NC}"
  echo "Response: $ME_BODY"
  exit 1
fi

# Count workflows
WORKFLOW_COUNT=$(ls -1 "$WORKFLOWS_DIR"/*.json 2>/dev/null | wc -l)

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No workflow files found in $WORKFLOWS_DIR/${NC}"
  exit 1
fi

echo "📊 Found $WORKFLOW_COUNT workflow file(s)"
echo ""

# Import workflows
IMPORTED=0
FAILED=0

echo "📥 Importing workflows..."
echo "───────────────────────────────────────"

for workflow_file in "$WORKFLOWS_DIR"/*.json; do
  WORKFLOW_NAME=$(basename "$workflow_file" .json)
  
  echo -n "[$(($IMPORTED + $FAILED + 1))/$WORKFLOW_COUNT] Importing $WORKFLOW_NAME ... "
  
  WORKFLOW_JSON=$(cat "$workflow_file")
  
  IMPORT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -X POST "${N8N_URL}/rest/workflows" \
    -d "$WORKFLOW_JSON" 2>&1)
  
  IMPORT_HTTP_CODE=$(echo "$IMPORT_RESPONSE" | tail -n1)
  IMPORT_BODY=$(echo "$IMPORT_RESPONSE" | sed '$d')
  
  if [ "$IMPORT_HTTP_CODE" -ne 200 ] && [ "$IMPORT_HTTP_CODE" -ne 201 ]; then
    echo -e "${RED}❌ Failed (HTTP $IMPORT_HTTP_CODE)${NC}"
    echo "   Response: ${IMPORT_BODY:0:150}..."
    FAILED=$((FAILED + 1))
    continue
  fi
  
  WORKFLOW_ID=$(echo "$IMPORT_BODY" | grep -oP '"id":\s*"\K[^"]+' | head -1)
  
  if [ -z "$WORKFLOW_ID" ]; then
    echo -e "${RED}❌ Failed (no ID returned)${NC}"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  echo -e "${GREEN}✅ Imported (ID: $WORKFLOW_ID)${NC}"
  
  # Activate workflow
  ACTIVATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -X PATCH "${N8N_URL}/rest/workflows/${WORKFLOW_ID}" \
    -d '{"active": true}' 2>&1)
  
  ACTIVATE_HTTP_CODE=$(echo "$ACTIVATE_RESPONSE" | tail -n1)
  ACTIVATE_BODY=$(echo "$ACTIVATE_RESPONSE" | sed '$d')
  
  if [ "$ACTIVATE_HTTP_CODE" -eq 200 ] && echo "$ACTIVATE_BODY" | grep -qi '"active".*true'; then
    echo "   ✅ Activated successfully"
    IMPORTED=$((IMPORTED + 1))
  else
    echo -e "   ${YELLOW}⚠️  Failed to activate (HTTP $ACTIVATE_HTTP_CODE)${NC}"
    IMPORTED=$((IMPORTED + 1))  # Still count as imported
  fi
  
  sleep 0.5
done

echo ""
echo "═══════════════════════════════════════"
echo "📊 Import Summary"
echo "═══════════════════════════════════════"
echo "  Total:    $WORKFLOW_COUNT"
echo -e "  Imported: ${GREEN}$IMPORTED${NC}"
echo -e "  Failed:   ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}🎉 All workflows imported successfully!${NC}"
  exit 0
else
  echo -e "${RED}⚠️  Some workflows failed to import!${NC}"
  exit 1
fi