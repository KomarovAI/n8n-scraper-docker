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
POSTGRES_USER="${POSTGRES_USER:-scraper_user}"
POSTGRES_DB="${POSTGRES_DB:-scraper_db}"
MAX_MIGRATION_WAIT=60  # seconds
MAX_AUTH_WAIT=60       # seconds for auth middleware init

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

# Force reset environment if credentials don't match
if [ "$NEED_RESET" = true ]; then
  echo "🧹 Full environment reset required..."
  echo ""
  
  # ═══════════════════════════════════════════════════════════════
  # CRITICAL SECTION: Complete environment recreation
  # This ensures n8n migrations run from scratch
  # ═══════════════════════════════════════════════════════════════
  
  echo "⏸️  Step 1/6: Stopping all services..."
  docker compose stop n8n postgres redis > /dev/null 2>&1
  echo -e "${GREEN}✅ Services stopped${NC}"
  echo ""
  
  echo "🗑️  Step 2/6: Removing containers..."
  docker compose rm -f n8n postgres redis > /dev/null 2>&1
  echo -e "${GREEN}✅ Containers removed${NC}"
  echo ""
  
  echo "🗑️  Step 3/6: Removing volumes (CRITICAL for migration trigger)..."
  docker volume rm n8n-scraper-docker_postgres-data 2>/dev/null || true
  docker volume rm n8n-scraper-docker_n8n-data 2>/dev/null || true
  docker volume rm n8n-scraper-docker_redis-data 2>/dev/null || true
  echo -e "${GREEN}✅ Clean slate achieved - migrations will run!${NC}"
  echo ""
  
  echo "🚀 Step 4/6: Starting fresh database..."
  docker compose up -d postgres redis > /dev/null 2>&1
  echo -e "${GREEN}✅ Database containers started${NC}"
  echo ""
  
  echo "⏳ Step 5/6: Waiting for PostgreSQL full readiness..."
  PG_READY_ATTEMPTS=0
  PG_MAX_ATTEMPTS=30
  
  while [ $PG_READY_ATTEMPTS -lt $PG_MAX_ATTEMPTS ]; do
    PG_READY_ATTEMPTS=$((PG_READY_ATTEMPTS + 1))
    
    if docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; then
      echo -e "${GREEN}✅ PostgreSQL is ready! (attempt $PG_READY_ATTEMPTS/$PG_MAX_ATTEMPTS)${NC}"
      break
    fi
    
    if [ $PG_READY_ATTEMPTS -eq $PG_MAX_ATTEMPTS ]; then
      echo -e "${RED}❌ PostgreSQL not ready after 90 seconds!${NC}"
      exit 1
    fi
    
    echo "   ⏳ Waiting for PostgreSQL... (attempt $PG_READY_ATTEMPTS/$PG_MAX_ATTEMPTS)"
    sleep 3
  done
  
  # Additional delay for full initialization
  sleep 5
  echo ""
  
  echo "🚀 Step 6/6: Starting n8n (will run ALL migrations)..."
  docker compose up -d n8n > /dev/null 2>&1
  echo -e "${GREEN}✅ n8n container started${NC}"
  echo ""
  
  # ═══════════════════════════════════════════════════════════════
  # Wait for n8n migrations to complete
  # We check the migrations table to confirm UserManagement ran
  # ═══════════════════════════════════════════════════════════════
  
  echo "⏳ Waiting for n8n migration to complete (max ${MAX_MIGRATION_WAIT}s)..."
  START_TIME=$(date +%s)
  MIGRATION_CHECK_ATTEMPTS=0
  MAX_MIGRATION_CHECK_ATTEMPTS=20  # 20 × 3 = 60 seconds
  MIGRATION_COMPLETE=false
  
  while [ $MIGRATION_CHECK_ATTEMPTS -lt $MAX_MIGRATION_CHECK_ATTEMPTS ]; do
    MIGRATION_CHECK_ATTEMPTS=$((MIGRATION_CHECK_ATTEMPTS + 1))
    ELAPSED=$(($(date +%s) - START_TIME))
    
    # Check if UserManagement migration exists
    MIGRATION_COUNT=$(docker compose exec -T postgres \
      psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t \
      -c "SELECT COUNT(*) FROM migrations WHERE name LIKE '%UserManagement%';" \
      2>/dev/null | tr -d ' ' || echo "0")
    
    if [ "$MIGRATION_COUNT" -gt "0" ]; then
      echo -e "${GREEN}✅ Migration completed! (attempt $MIGRATION_CHECK_ATTEMPTS/$MAX_MIGRATION_CHECK_ATTEMPTS)${NC}"
      MIGRATION_COMPLETE=true
      break
    fi
    
    if [ "$ELAPSED" -ge "$MAX_MIGRATION_WAIT" ]; then
      echo -e "${RED}❌ Migration not completed within ${MAX_MIGRATION_WAIT} seconds!${NC}"
      echo "   Check n8n logs: docker compose logs n8n"
      exit 1
    fi
    
    echo "   ⏳ Waiting for migration... (attempt $MIGRATION_CHECK_ATTEMPTS/$MAX_MIGRATION_CHECK_ATTEMPTS)"
    sleep 3
  done
  
  if [ "$MIGRATION_COMPLETE" = false ]; then
    echo -e "${RED}❌ Migration verification failed!${NC}"
    exit 1
  fi
  
  # Small delay to ensure roles are fully written
  sleep 5
  echo ""
  
  # ═══════════════════════════════════════════════════════════════
  # Verify n8n API is accessible
  # ═══════════════════════════════════════════════════════════════
  
  echo "⏳ Verifying n8n API accessibility..."
  N8N_READY_ATTEMPTS=0
  N8N_MAX_ATTEMPTS=30
  
  while [ $N8N_READY_ATTEMPTS -lt $N8N_MAX_ATTEMPTS ]; do
    N8N_READY_ATTEMPTS=$((N8N_READY_ATTEMPTS + 1))
    
    if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1 || \
       curl -sf "${N8N_URL}" > /dev/null 2>&1; then
      echo -e "${GREEN}✅ n8n API is accessible! (attempt $N8N_READY_ATTEMPTS/$N8N_MAX_ATTEMPTS)${NC}"
      break
    fi
    
    if [ $N8N_READY_ATTEMPTS -eq $N8N_MAX_ATTEMPTS ]; then
      echo -e "${RED}❌ n8n API not accessible after 90 seconds!${NC}"
      exit 1
    fi
    
    echo "   ⏳ Waiting for n8n API... (attempt $N8N_READY_ATTEMPTS/$N8N_MAX_ATTEMPTS)"
    sleep 3
  done
  echo ""
  
  # ═══════════════════════════════════════════════════════════════
  # Create owner with current credentials
  # ═══════════════════════════════════════════════════════════════
  
  echo "🔧 Creating new owner with current credentials..."
  
  SETUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
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
  
  HTTP_CODE=$(echo "$SETUP_RESPONSE" | tail -n1)
  RESPONSE_BODY=$(echo "$SETUP_RESPONSE" | sed '$d')
  
  if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ] || echo "$RESPONSE_BODY" | grep -qi '"id"'; then
    echo -e "${GREEN}✅ Owner created successfully${NC}"
  else
    echo -e "${RED}❌ Failed to create owner (HTTP $HTTP_CODE)${NC}"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "Debug info:"
    docker compose logs --tail=50 n8n
    exit 1
  fi
  echo ""
  
  # ═══════════════════════════════════════════════════════════════
  # CRITICAL: Wait for auth middleware to fully initialize
  # Owner creation triggers async auth restart (10-15 seconds)
  # ═══════════════════════════════════════════════════════════════
  
  echo "⏳ Allowing auth middleware to fully initialize (15s mandatory pause)..."
  sleep 15
  echo -e "${GREEN}✅ Initial auth initialization complete${NC}"
  echo ""
  
  echo "⏳ Verifying full auth readiness via /api/v1/me endpoint..."
  AUTH_READY_ATTEMPTS=0
  AUTH_MAX_ATTEMPTS=20  # 20 × 3s = 60 seconds
  AUTH_READY=false
  
  while [ $AUTH_READY_ATTEMPTS -lt $AUTH_MAX_ATTEMPTS ]; do
    AUTH_READY_ATTEMPTS=$((AUTH_READY_ATTEMPTS + 1))
    
    # Check /api/v1/me - requires FULL auth initialization
    ME_RESPONSE=$(curl -s -w "\n%{http_code}" \
      -u "${N8N_USER}:${N8N_PASSWORD}" \
      "${N8N_URL}/api/v1/me" 2>&1)
    
    ME_HTTP_CODE=$(echo "$ME_RESPONSE" | tail -n1)
    
    if [ "$ME_HTTP_CODE" -eq 200 ]; then
      echo -e "${GREEN}✅ Auth middleware fully ready! (attempt $AUTH_READY_ATTEMPTS/$AUTH_MAX_ATTEMPTS)${NC}"
      AUTH_READY=true
      break
    fi
    
    if [ $AUTH_READY_ATTEMPTS -eq $AUTH_MAX_ATTEMPTS ]; then
      echo -e "${RED}❌ Auth middleware not ready after ${MAX_AUTH_WAIT} seconds!${NC}"
      echo "Last HTTP code: $ME_HTTP_CODE"
      echo ""
      echo "Debug info:"
      docker compose logs --tail=100 n8n
      exit 1
    fi
    
    echo "   ⏳ Auth initializing... (attempt $AUTH_READY_ATTEMPTS/$AUTH_MAX_ATTEMPTS, last code: $ME_HTTP_CODE)"
    sleep 3
  done
  
  if [ "$AUTH_READY" = false ]; then
    echo -e "${RED}❌ Auth readiness verification failed!${NC}"
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
  
  # ═══════════════════════════════════════════════════════════════
  # Import workflow with retry logic (handles remaining race conditions)
  # ═══════════════════════════════════════════════════════════════
  
  IMPORT_SUCCESS=false
  for RETRY_ATTEMPT in {1..3}; do
    IMPORT_RESPONSE=$(curl -s -w "\n%{http_code}" \
      -H "${AUTH_HEADER}" \
      -H "Content-Type: application/json" \
      -X POST \
      "${N8N_URL}/rest/workflows" \
      -d "$WORKFLOW_JSON" \
      2>&1)
    
    IMPORT_HTTP_CODE=$(echo "$IMPORT_RESPONSE" | tail -n1)
    IMPORT_BODY=$(echo "$IMPORT_RESPONSE" | sed '$d')
    
    if [ "$IMPORT_HTTP_CODE" -eq 200 ] || [ "$IMPORT_HTTP_CODE" -eq 201 ]; then
      IMPORT_SUCCESS=true
      break
    elif [ "$IMPORT_HTTP_CODE" -eq 401 ] && [ "$RETRY_ATTEMPT" -lt 3 ]; then
      # 401 = auth might still be warming up, retry with backoff
      BACKOFF_TIME=$((RETRY_ATTEMPT * 2))
      echo ""
      echo "   ⚠️  Got 401, retrying in ${BACKOFF_TIME}s... (attempt $RETRY_ATTEMPT/3)"
      sleep $BACKOFF_TIME
      echo -n "   "
    else
      # Other error or max retries reached
      break
    fi
  done
  
  if [ "$IMPORT_SUCCESS" = false ]; then
    echo -e "${RED}❌ Failed (HTTP $IMPORT_HTTP_CODE after $RETRY_ATTEMPT attempts)${NC}"
    echo "   Response: ${IMPORT_BODY:0:150}..."
    FAILED=$((FAILED + 1))
    continue
  fi
  
  # Extract workflow ID
  WORKFLOW_ID=$(echo "$IMPORT_BODY" | grep -oP '"id":\s*"\K[^"]+' | head -1)
  
  if [ -z "$WORKFLOW_ID" ]; then
    echo -e "${RED}❌ Failed (no ID returned)${NC}"
    echo "   Response: ${IMPORT_BODY:0:100}..."
    FAILED=$((FAILED + 1))
    continue
  fi
  
  echo -e "${GREEN}✅ Imported (ID: $WORKFLOW_ID)${NC}"
  
  # ═══════════════════════════════════════════════════════════════
  # Activate workflow with retry logic
  # ═══════════════════════════════════════════════════════════════
  
  ACTIVATE_SUCCESS=false
  for RETRY_ATTEMPT in {1..2}; do
    ACTIVATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
      -H "${AUTH_HEADER}" \
      -H "Content-Type: application/json" \
      -X PATCH \
      "${N8N_URL}/rest/workflows/${WORKFLOW_ID}" \
      -d '{"active": true}' \
      2>&1)
    
    ACTIVATE_HTTP_CODE=$(echo "$ACTIVATE_RESPONSE" | tail -n1)
    ACTIVATE_BODY=$(echo "$ACTIVATE_RESPONSE" | sed '$d')
    
    if [ "$ACTIVATE_HTTP_CODE" -eq 200 ] && echo "$ACTIVATE_BODY" | grep -qi '"active".*true'; then
      ACTIVATE_SUCCESS=true
      break
    elif [ "$RETRY_ATTEMPT" -lt 2 ]; then
      sleep 2
    fi
  done
  
  if [ "$ACTIVATE_SUCCESS" = true ]; then
    echo "   ✅ Activated successfully"
    IMPORTED=$((IMPORTED + 1))
  else
    echo -e "   ${YELLOW}⚠️  Failed to activate (HTTP $ACTIVATE_HTTP_CODE)${NC}"
    echo "   Response: ${ACTIVATE_BODY:0:100}..."
    IMPORTED=$((IMPORTED + 1))  # Count as imported even if activation failed
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