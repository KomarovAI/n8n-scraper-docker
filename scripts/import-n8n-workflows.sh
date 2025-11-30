#!/bin/bash
# Import n8n workflows via API and activate them
# Uses n8n 1.x User Management (owner setup + cookie authentication)
# 
# CRITICAL: n8n v1.0+ removed Basic Auth support!
# Source: https://docs.n8n.io/1-0-migration-checklist/
# "removes support for other authentication methods, such as BasicAuth"

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📦 n8n Workflow Import & Activation (n8n 1.x API)"
echo "═════════════════════════════════════════════"
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

# ══════════════════════════════════════════════════════════════════
# n8n 1.x USER MANAGEMENT AUTHENTICATION
# 
# ВАЖНО: n8n v1.0+ УДАЛИЛ Basic Auth!
# Источник: https://docs.n8n.io/1-0-migration-checklist/
# 
# Новый подход (n8n 1.x):
#   1. Создать owner через POST /rest/owner/setup (если ещё не создан)
#   2. Получить cookie n8n-auth
#   3. Использовать cookie для всех API запросов
# ══════════════════════════════════════════════════════════════════

echo "🔧 Setting up n8n owner account..."

# Попытка создать owner (если уже создан - получим 400)
OWNER_SETUP=$(curl -s -w "\n%{http_code}" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_FILE" \
  -X POST "${N8N_URL}/rest/owner/setup" \
  -d "{
    \"email\": \"${N8N_USER}\",
    \"firstName\": \"Admin\",
    \"lastName\": \"User\",
    \"password\": \"${N8N_PASSWORD}\"
  }" 2>&1)

OWNER_HTTP_CODE=$(echo "$OWNER_SETUP" | tail -n1)
OWNER_BODY=$(echo "$OWNER_SETUP" | sed '$d')

if [ "$OWNER_HTTP_CODE" -eq 200 ]; then
  echo -e "${GREEN}✅ Owner created successfully (first-time setup)${NC}"
elif [ "$OWNER_HTTP_CODE" -eq 400 ]; then
  echo -e "${YELLOW}⚠️  Owner already exists, logging in...${NC}"
  
  # Owner уже создан, делаем login для получения cookie
  LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" \
    -X POST "${N8N_URL}/rest/login" \
    -d "{
      \"email\": \"${N8N_USER}\",
      \"password\": \"${N8N_PASSWORD}\"
    }" 2>&1)
  
  LOGIN_HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
  LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')
  
  if [ "$LOGIN_HTTP_CODE" -ne 200 ]; then
    echo -e "${RED}❌ Login failed (HTTP $LOGIN_HTTP_CODE)${NC}"
    echo "Response: ${LOGIN_BODY:0:200}"
    exit 1
  fi
  
  echo -e "${GREEN}✅ Logged in successfully${NC}"
else
  echo -e "${RED}❌ Owner setup failed (HTTP $OWNER_HTTP_CODE)${NC}"
  echo "Response: ${OWNER_BODY:0:200}"
  exit 1
fi

# Проверяем что cookie был получен
if [ ! -f "$COOKIE_FILE" ] || ! grep -q 'n8n-auth' "$COOKIE_FILE"; then
  echo -e "${RED}❌ Failed to get authentication cookie!${NC}"
  exit 1
fi

echo ""

# Проверяем доступ к API с cookie
echo "🔍 Verifying API access with cookie..."

API_CHECK=$(curl -s -w "\n%{http_code}" \
  -b "$COOKIE_FILE" \
  "${N8N_URL}/rest/workflows" 2>&1)

API_STATUS=$(echo "$API_CHECK" | tail -n1)
API_BODY=$(echo "$API_CHECK" | sed '$d')

if [ "$API_STATUS" -eq 200 ]; then
  echo -e "${GREEN}✅ API access verified${NC}"
else
  echo -e "${RED}❌ API access failed (HTTP $API_STATUS)${NC}"
  echo "Response: ${API_BODY:0:200}"
  echo ""
  echo -e "${YELLOW}⚠️  Troubleshooting:${NC}"
  echo "   1. Check n8n logs: docker logs n8n-app"
  echo "   2. Verify credentials are correct"
  echo "   3. Ensure n8n version >= 1.0 (User Management mode)"
  exit 1
fi

echo ""

# ══════════════════════════════════════════════════════════════════
# IMPORT WORKFLOWS
# ══════════════════════════════════════════════════════════════════

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
echo "───────────────────────────────────────────"

for workflow_file in "$WORKFLOWS_DIR"/*.json; do
  WORKFLOW_NAME=$(basename "$workflow_file" .json)
  
  echo -n "[$(($IMPORTED + $FAILED + 1))/$WORKFLOW_COUNT] Importing $WORKFLOW_NAME ... "
  
  WORKFLOW_JSON=$(cat "$workflow_file")
  
  IMPORT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -b "$COOKIE_FILE" \
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
    -b "$COOKIE_FILE" \
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

# Cleanup cookie file
rm -f "$COOKIE_FILE"

echo ""
echo "═══════════════════════════════════════════"
echo "📊 Import Summary"
echo "═══════════════════════════════════════════"
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