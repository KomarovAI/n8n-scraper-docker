#!/bin/bash
# Import n8n workflows via API and activate them
# Uses Basic Authentication (compatible with N8N_BASIC_AUTH_ACTIVE=true)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📦 n8n Workflow Import & Activation"
echo "═══════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin@example.com}"
N8N_PASSWORD="${N8N_PASSWORD}"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-workflows}"

if [ -z "$N8N_PASSWORD" ]; then
  echo -e "${RED}❌ N8N_PASSWORD not set!${NC}"
  exit 1
fi

if [ -z "$N8N_USER" ]; then
  echo -e "${RED}❌ N8N_USER not set!${NC}"
  exit 1
fi

# Validate password length
if [ ${#N8N_PASSWORD} -lt 8 ]; then
  echo -e "${RED}❌ Password too short! Minimum 8 characters required.${NC}"
  echo "   Current length: ${#N8N_PASSWORD}"
  exit 1
fi

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   n8n User: $N8N_USER"
echo "   Password length: ${#N8N_PASSWORD} chars"
echo "   Workflows dir: $WORKFLOWS_DIR"
echo ""

# Check n8n availability
echo "🔍 Checking n8n availability..."
if ! curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1 && \
   ! curl -sf "${N8N_URL}" > /dev/null 2>&1; then
  echo -e "${RED}❌ n8n is not accessible at $N8N_URL${NC}"
  exit 1
fi
echo -e "${GREEN}✅ n8n is accessible${NC}"
echo ""

# Generate Basic Auth header
echo "🔐 Setting up Basic Authentication..."
BASIC_AUTH=$(echo -n "${N8N_USER}:${N8N_PASSWORD}" | base64)
AUTH_HEADER="Authorization: Basic ${BASIC_AUTH}"
echo -e "${GREEN}✅ Basic Auth header created${NC}"
echo ""

# Test if current credentials work
echo "🔍 Testing credentials..."
LOGIN_TEST=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  "${N8N_URL}/rest/login" \
  -d "{
    \"email\": \"${N8N_USER}\",
    \"password\": \"${N8N_PASSWORD}\"
  }" \
  2>&1)

if echo "$LOGIN_TEST" | grep -qi '"id"'; then
  echo -e "${GREEN}✅ Credentials valid${NC}"
  NEED_RESET=false
elif echo "$LOGIN_TEST" | grep -qi 'unauthorized\|wrong.*password\|invalid.*credentials'; then
  echo -e "${YELLOW}⚠️  Credentials mismatch detected!${NC}"
  echo "   Old owner exists with different password"
  NEED_RESET=true
else
  # Owner doesn't exist yet
  echo -e "${YELLOW}⚠️  No owner found${NC}"
  NEED_RESET=true
fi
echo ""

# Force reset owner if credentials don't match
if [ "$NEED_RESET" = true ]; then
  echo "🔧 Resetting n8n owner..."
  
  # Delete all users from postgres (force clean)
  echo "🗑️  Removing old owner from database..."
  
  # Use docker compose exec with proper postgres credentials
  PGPASSWORD="${POSTGRES_PASSWORD}" docker compose exec -T postgres \
    psql -U "${POSTGRES_USER:-scraper_user}" -d "${POSTGRES_DB:-scraper_db}" \
    -c "DELETE FROM \"user\";" 2>/dev/null || true
  
  echo -e "${GREEN}✅ Old owner removed${NC}"
  
  # Wait for n8n to detect no owner
  sleep 2
  
  echo "🔧 Creating new owner with current credentials..."
  
  # Setup owner
  SETUP_RESPONSE=$(curl -s -X POST \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    "${N8N_URL}/rest/owner/setup" \
    -d "{
      \"email\": \"${N8N_USER}\",
      \"password\": \"${N8N_PASSWORD}\",
      \"firstName\": \"CI\",
      \"lastName\": \"User\"
    }" \
    2>&1)
  
  if echo "$SETUP_RESPONSE" | grep -qi '"id"'; then
    echo -e "${GREEN}✅ Owner created successfully${NC}"
  else
    echo -e "${RED}❌ Failed to create owner${NC}"
    echo "Response: $SETUP_RESPONSE"
    exit 1
  fi
fi
echo ""

# Count workflows
WORKFLOW_COUNT=$(ls -1 "$WORKFLOWS_DIR"/*.json 2>/dev/null | wc -l)

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No workflow files found in $WORKFLOWS_DIR/${NC}"
  exit 1
fi

echo "📊 Found $WORKFLOW_COUNT workflow file(s)"
echo ""

# Import each workflow
IMPORTED=0
FAILED=0

echo "📥 Importing workflows..."
echo "───────────────────────────────────────"

for workflow_file in "$WORKFLOWS_DIR"/*.json; do
  WORKFLOW_NAME=$(basename "$workflow_file" .json)
  
  echo -n "[$(($IMPORTED + $FAILED + 1))/$WORKFLOW_COUNT] Importing $WORKFLOW_NAME ... "
  
  # Read workflow JSON
  WORKFLOW_JSON=$(cat "$workflow_file")
  
  # Import workflow via API (using Basic Auth - no login session needed!)
  IMPORT_RESPONSE=$(curl -s \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -X POST \
    "${N8N_URL}/rest/workflows" \
    -d "$WORKFLOW_JSON" \
    2>&1)
  
  # Check if import succeeded
  if echo "$IMPORT_RESPONSE" | grep -qi '"id"'; then
    # Extract workflow ID
    WORKFLOW_ID=$(echo "$IMPORT_RESPONSE" | grep -oP '"id":\s*"\K[^"]+' | head -1)
    
    if [ -n "$WORKFLOW_ID" ]; then
      echo -e "${GREEN}✅ Imported (ID: $WORKFLOW_ID)${NC}"
      
      # Activate workflow (using Basic Auth)
      ACTIVATE_RESPONSE=$(curl -s \
        -H "${AUTH_HEADER}" \
        -H "Content-Type: application/json" \
        -X PATCH \
        "${N8N_URL}/rest/workflows/${WORKFLOW_ID}" \
        -d '{"active": true}' \
        2>&1)
      
      if echo "$ACTIVATE_RESPONSE" | grep -qi '"active".*true'; then
        echo "   ✅ Activated successfully"
      else
        echo -e "   ${YELLOW}⚠️  Failed to activate${NC}"
        echo "   Response: ${ACTIVATE_RESPONSE:0:100}..."
      fi
      
      IMPORTED=$((IMPORTED + 1))
    else
      echo -e "${RED}❌ Failed (no ID returned)${NC}"
      echo "   Response: ${IMPORT_RESPONSE:0:100}..."
      FAILED=$((FAILED + 1))
    fi
  else
    echo -e "${RED}❌ Failed${NC}"
    echo "   Response: ${IMPORT_RESPONSE:0:100}..."
    FAILED=$((FAILED + 1))
  fi
  
  sleep 1
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
