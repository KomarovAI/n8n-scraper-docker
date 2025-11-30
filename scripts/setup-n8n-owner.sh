#!/bin/bash
# Automated n8n owner setup for CI/CD
# Based on community best practices:
# - https://community.latenode.com/t/how-can-i-automatically-configure-admin-user-during-n8n-self-hosted-deployment/29790
# - https://stackoverflow.com/questions/77733981/is-there-a-way-to-programmatically-set-the-owner-account-for-a-selfhosted-n8n-in

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔧 n8n Owner Setup (Automated)"
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
# STEP 1: CHECK IF OWNER EXISTS
# ═══════════════════════════════════════════════════════

echo "🔍 Step 1: Checking if owner exists..."
echo "──────────────────────────────────────────"

OWNER_CHECK=$(curl -s "${N8N_URL}/rest/owner" 2>&1 || echo "")

if echo "$OWNER_CHECK" | grep -qi '"firstName"'; then
  echo -e "${GREEN}✅ Owner already exists${NC}"
  echo ""
  echo "Owner details:"
  echo "$OWNER_CHECK" | grep -oP '"firstName":"\K[^"]+' | head -1 | xargs -I {} echo "   First Name: {}"
  echo "$OWNER_CHECK" | grep -oP '"lastName":"\K[^"]+' | head -1 | xargs -I {} echo "   Last Name: {}"
  echo "$OWNER_CHECK" | grep -oP '"email":"\K[^"]+' | head -1 | xargs -I {} echo "   Email: {}"
  echo ""
  echo -e "${BLUE}ℹ️  Skipping owner creation (idempotent operation)${NC}"
  echo ""
  exit 0
fi

echo -e "${YELLOW}⚠️  No owner found, creating...${NC}"
echo ""

# ═══════════════════════════════════════════════════════
# STEP 2: CREATE OWNER ACCOUNT
# Official n8n REST API endpoint: POST /rest/owner/setup
# ═══════════════════════════════════════════════════════

echo "🔧 Step 2: Creating owner account..."
echo "──────────────────────────────────────────"

SETUP_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Content-Type: application/json" \
  -X POST "${N8N_URL}/rest/owner/setup" \
  -d "{
    \"email\": \"${N8N_USER}\",
    \"password\": \"${N8N_PASSWORD}\",
    \"firstName\": \"CI\",
    \"lastName\": \"Pipeline\"
  }" 2>&1)

SETUP_HTTP_CODE=$(echo "$SETUP_RESPONSE" | tail -n1)
SETUP_BODY=$(echo "$SETUP_RESPONSE" | sed '$d')

if [ "$SETUP_HTTP_CODE" -ne 200 ] && [ "$SETUP_HTTP_CODE" -ne 201 ]; then
  echo -e "${RED}❌ Owner setup failed (HTTP $SETUP_HTTP_CODE)${NC}"
  echo ""
  echo "Response:"
  echo "$SETUP_BODY"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if n8n is accessible: curl ${N8N_URL}/healthz"
  echo "  2. Verify n8n logs: docker compose logs n8n"
  echo "  3. Ensure database is initialized: docker compose logs postgres"
  exit 1
fi

if ! echo "$SETUP_BODY" | grep -qi '"email"'; then
  echo -e "${RED}❌ Owner setup failed (invalid response)${NC}"
  echo ""
  echo "Response:"
  echo "$SETUP_BODY"
  exit 1
fi

echo -e "${GREEN}✅ Owner created successfully${NC}"
echo ""
echo "Owner details:"
echo "   Email: $N8N_USER"
echo "   First Name: CI"
echo "   Last Name: Pipeline"
echo ""

# ═══════════════════════════════════════════════════════
# STEP 3: VERIFICATION
# ═══════════════════════════════════════════════════════

echo "🔍 Step 3: Verifying owner creation..."
echo "──────────────────────────────────────────"

sleep 2

VERIFY=$(curl -s "${N8N_URL}/rest/owner" 2>&1)

if echo "$VERIFY" | grep -qi '"firstName"'; then
  echo -e "${GREEN}✅ Owner verification successful${NC}"
  echo ""
  echo -e "${GREEN}🎉 n8n owner setup complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Create API Key: n8n UI → Settings → n8n API → Create API key"
  echo "  2. Add to GitHub Secrets: N8N_API_KEY=n8n_api_xxxxx"
  echo "  3. Run workflow: bash scripts/init-workflows-api-key.sh"
  exit 0
else
  echo -e "${RED}❌ Owner verification failed${NC}"
  echo ""
  echo "Response:"
  echo "$VERIFY"
  exit 1
fi
