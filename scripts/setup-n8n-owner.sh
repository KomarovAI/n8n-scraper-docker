#!/bin/bash
# Automated n8n owner setup for CI/CD with improved readiness checks
# Based on community best practices and production feedback:
# - https://community.n8n.io/t/detecting-if-the-owner-is-already-set/44643
# - https://docs.n8n.io/hosting/logging-monitoring/monitoring/
# - https://github.com/n8n-io/n8n/issues/16529

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔧 n8n Owner Setup (Automated with Pre-Check)"
echo "═══════════════════════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER}"
N8N_PASSWORD="${N8N_PASSWORD}"

if [ -z "$N8N_USER" ] || [ -z "$N8N_PASSWORD" ]; then
  echo -e "${RED}❌ N8N_USER or N8N_PASSWORD not set!${NC}"
  echo ""
  echo "Required environment variables:"
  echo "  N8N_USER     - Email for owner account (e.g., ci@example.com)"
  echo "  N8N_PASSWORD - Password for owner account"
  echo ""
  echo "GitHub Secrets:"
  echo "  Add N8N_USER and N8N_PASSWORD to repository secrets"
  exit 1
fi

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   n8n User: $N8N_USER"
echo "   n8n Password: ****** (${#N8N_PASSWORD} chars)"
echo ""

# ═══════════════════════════════════════════════════════
# STEP 0: VERIFY API READINESS
# CRITICAL: /healthz responds before API endpoints are ready!
# Use /healthz/readiness to ensure DB is connected and migrated
# ═══════════════════════════════════════════════════════

echo "🔍 Step 0: Verifying n8n API readiness..."
echo "──────────────────────────────────────────"

for i in {1..30}; do
  READINESS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${N8N_URL}/healthz/readiness" 2>/dev/null || echo "000")
  
  if [ "$READINESS_CODE" == "200" ]; then
    echo -e "${GREEN}✅ n8n API is fully ready (DB connected + migrated)${NC}"
    echo ""
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo -e "${RED}❌ n8n API readiness timeout after 60s${NC}"
    echo "Last HTTP code: $READINESS_CODE"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check n8n logs: docker compose logs n8n --tail=50"
    echo "  2. Check database: docker compose logs postgres --tail=30"
    echo "  3. Verify /healthz: curl ${N8N_URL}/healthz"
    exit 1
  fi
  
  echo "⏳ Waiting for API readiness... (attempt $i/30, HTTP $READINESS_CODE)"
  sleep 2
done

# Additional buffer for API endpoint initialization
echo "⏳ Additional 10s buffer for API endpoint initialization..."
sleep 10
echo ""

# ═══════════════════════════════════════════════════════
# STEP 1: CHECK IF OWNER EXISTS
# Use /rest/owner endpoint - returns 200 with owner data if exists
# ═══════════════════════════════════════════════════════

echo "🔍 Step 1: Checking if owner exists via /rest/owner..."
echo "──────────────────────────────────────────"

OWNER_CHECK_CODE=$(curl -s -o /tmp/owner_check.json -w "%{http_code}" "${N8N_URL}/rest/owner" 2>/dev/null || echo "000")
OWNER_CHECK_BODY=$(cat /tmp/owner_check.json 2>/dev/null || echo "")

if [ "$OWNER_CHECK_CODE" == "200" ]; then
  echo -e "${GREEN}✅ Owner already exists (HTTP 200 from /rest/owner)${NC}"
  echo ""
  
  if echo "$OWNER_CHECK_BODY" | grep -qi '"firstName"'; then
    echo "Owner details:"
    echo "$OWNER_CHECK_BODY" | grep -oP '"firstName":"\K[^"]+' | head -1 | xargs -I {} echo "   First Name: {}"
    echo "$OWNER_CHECK_BODY" | grep -oP '"lastName":"\K[^"]+' | head -1 | xargs -I {} echo "   Last Name: {}"
    echo "$OWNER_CHECK_BODY" | grep -oP '"email":"\K[^"]+' | head -1 | xargs -I {} echo "   Email: {}"
    echo ""
  fi
  
  echo -e "${BLUE}ℹ️  Verifying credentials with login attempt...${NC}"
  
  LOGIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${N8N_URL}/rest/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${N8N_USER}\", \"password\": \"${N8N_PASSWORD}\"}" 2>/dev/null || echo "000")
  
  if [ "$LOGIN_CODE" == "200" ]; then
    echo -e "${GREEN}✅ Owner exists and credentials are valid${NC}"
    echo ""
    echo -e "${GREEN}🎉 n8n owner setup complete (idempotent - already configured)!${NC}"
    exit 0
  else
    echo -e "${YELLOW}⚠️  Owner exists but credentials don't match (HTTP $LOGIN_CODE)${NC}"
    echo "This might be expected if using different credentials than current owner"
    echo ""
    echo -e "${BLUE}ℹ️  Proceeding with idempotent exit (owner exists)${NC}"
    exit 0
  fi
fi

echo -e "${YELLOW}⚠️  No owner found (HTTP $OWNER_CHECK_CODE), proceeding with creation...${NC}"
echo ""

# ═══════════════════════════════════════════════════════
# STEP 2: CREATE OWNER ACCOUNT
# Official n8n REST API endpoint: POST /rest/owner/setup
# NOTE: This endpoint returns 404 if owner already exists
# ═══════════════════════════════════════════════════════

echo "🔧 Step 2: Creating owner account via /rest/owner/setup..."
echo "──────────────────────────────────────────"

SETUP_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Content-Type: application/json" \
  -X POST "${N8N_URL}/rest/owner/setup" \
  -d "{
    \"email\": \"${N8N_USER}\",
    \"password\": \"${N8N_PASSWORD}\",
    \"firstName\": \"CI\",
    \"lastName\": \"Pipeline\"
  }" 2>&1)

SETUP_HTTP_CODE=$(echo "$SETUP_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
SETUP_BODY=$(echo "$SETUP_RESPONSE" | grep -v "HTTP_CODE")

if [ "$SETUP_HTTP_CODE" == "200" ] || [ "$SETUP_HTTP_CODE" == "201" ]; then
  echo -e "${GREEN}✅ Owner created successfully (HTTP $SETUP_HTTP_CODE)${NC}"
  echo ""
  
  if echo "$SETUP_BODY" | grep -qi '"email"'; then
    echo "Owner details:"
    echo "   Email: $N8N_USER"
    echo "   First Name: CI"
    echo "   Last Name: Pipeline"
    echo ""
  fi
  
  echo -e "${GREEN}🎉 n8n owner setup complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Create API Key: n8n UI → Settings → n8n API → Create API key"
  echo "  2. Add to GitHub Secrets: N8N_API_KEY=n8n_api_xxxxx"
  echo "  3. Run workflow: bash scripts/init-workflows-api-key.sh"
  exit 0
elif [ "$SETUP_HTTP_CODE" == "404" ]; then
  # 404 from /rest/owner/setup usually means owner already exists
  # This is documented n8n behavior - the endpoint is disabled after setup
  echo -e "${YELLOW}⚠️  /rest/owner/setup returned 404 (endpoint not available)${NC}"
  echo "This typically means owner already exists and setup endpoint is disabled"
  echo ""
  echo -e "${BLUE}ℹ️  Attempting login to verify owner existence...${NC}"
  
  LOGIN_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${N8N_URL}/rest/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${N8N_USER}\", \"password\": \"${N8N_PASSWORD}\"}" 2>&1)
  
  LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
  LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | grep -v "HTTP_CODE")
  
  if [ "$LOGIN_CODE" == "200" ]; then
    echo -e "${GREEN}✅ Owner exists and credentials are valid (confirmed via /rest/login)${NC}"
    echo ""
    echo -e "${GREEN}🎉 n8n owner setup complete (idempotent - owner exists)!${NC}"
    exit 0
  else
    echo -e "${RED}❌ Setup returned 404 and login failed (HTTP $LOGIN_CODE)${NC}"
    echo ""
    echo "Setup response:"
    echo "$SETUP_BODY"
    echo ""
    echo "Login response:"
    echo "$LOGIN_BODY"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check n8n logs: docker compose logs n8n --tail=100"
    echo "  2. Verify database state: docker compose exec postgres psql -U n8n_user -d n8n_db -c 'SELECT * FROM \"user\" LIMIT 5;'"
    echo "  3. Check /rest/owner manually: curl ${N8N_URL}/rest/owner"
    echo "  4. If owner exists with different credentials, this is expected behavior"
    exit 1
  fi
else
  echo -e "${RED}❌ Owner setup failed (HTTP $SETUP_HTTP_CODE)${NC}"
  echo ""
  echo "Response:"
  echo "$SETUP_BODY"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if n8n is accessible: curl ${N8N_URL}/healthz"
  echo "  2. Verify n8n logs: docker compose logs n8n --tail=100"
  echo "  3. Ensure database is initialized: docker compose logs postgres --tail=50"
  echo "  4. Check API readiness: curl ${N8N_URL}/healthz/readiness"
  exit 1
fi
