#!/bin/bash
# Comprehensive n8n Webhook Diagnostic Script
# Provides detailed visibility into workflow and webhook states

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 N8N WEBHOOK DIAGNOSTIC REPORT${NC}"
echo "══════════════════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n-app}"
DB_CONTAINER="${DB_CONTAINER:-postgres}"
DB_NAME="${DB_NAME:-n8n}"
DB_USER="${DB_USER:-n8n}"

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   n8n Container: $N8N_CONTAINER"
echo "   Database: $DB_CONTAINER"
echo ""

# ═══════════════════════════════════════════════════════
# 1. N8N HEALTH CHECK
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}1️⃣  n8n Health Status${NC}"
echo "──────────────────────────────────────────────────"

HEALTH=$(curl -s "${N8N_URL}/healthz" 2>&1 || echo "ERROR")

if [ "$HEALTH" = "ERROR" ] || [ -z "$HEALTH" ]; then
  echo -e "${RED}❌ n8n not responding${NC}"
  echo "   URL: $N8N_URL/healthz"
else
  echo -e "${GREEN}✅ n8n is healthy${NC}"
  echo "   Response: $HEALTH"
fi

echo ""

# ═══════════════════════════════════════════════════════
# 2. ACTIVE WORKFLOWS
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}2️⃣  Active Workflows${NC}"
echo "──────────────────────────────────────────────────"

if docker ps | grep -q "$N8N_CONTAINER"; then
  WORKFLOW_LIST=$(docker exec "$N8N_CONTAINER" sh -c "n8n list:workflow 2>&1" || echo "ERROR")
  
  if [ "$WORKFLOW_LIST" = "ERROR" ] || [ -z "$WORKFLOW_LIST" ]; then
    echo -e "${RED}❌ Cannot list workflows via CLI${NC}"
  else
    echo "$WORKFLOW_LIST" | head -20
  fi
else
  echo -e "${RED}❌ Container $N8N_CONTAINER not running${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════
# 3. WEBHOOK NODE CONFIGURATION
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}3️⃣  Webhook Node Configuration${NC}"
echo "──────────────────────────────────────────────────"

if docker ps | grep -q "$N8N_CONTAINER"; then
  WEBHOOK_CONFIG=$(docker exec "$N8N_CONTAINER" sh -c \
    "find /home/node/.n8n/workflows -name '*.json' -exec grep -l 'n8n-nodes-base.webhook' {} \; 2>/dev/null | \
     head -1 | xargs cat 2>/dev/null" 2>&1 || echo "ERROR")
  
  if [ "$WEBHOOK_CONFIG" = "ERROR" ] || [ -z "$WEBHOOK_CONFIG" ]; then
    echo -e "${RED}❌ Cannot read workflow files${NC}"
  else
    echo "$WEBHOOK_CONFIG" | grep -E '"name"|"type":"n8n-nodes-base.webhook"|"path"|"httpMethod"|"responseMode"' | head -10
  fi
else
  echo -e "${RED}❌ Container $N8N_CONTAINER not running${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════
# 4. RECENT WORKFLOW EXECUTIONS
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}4️⃣  Recent Workflow Executions${NC}"
echo "──────────────────────────────────────────────────"

if docker ps | grep -q "$N8N_CONTAINER"; then
  EXECUTIONS=$(docker exec "$N8N_CONTAINER" sh -c "n8n list:execution --limit 10 2>&1" || echo "ERROR")
  
  if [ "$EXECUTIONS" = "ERROR" ] || [ -z "$EXECUTIONS" ]; then
    echo -e "${YELLOW}⚠️  No executions found or command failed${NC}"
  else
    echo "$EXECUTIONS" | head -20
  fi
else
  echo -e "${RED}❌ Container $N8N_CONTAINER not running${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════
# 5. WEBHOOK REGISTRATION LOGS
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}5️⃣  Webhook Registration Logs${NC}"
echo "──────────────────────────────────────────────────"

if docker ps | grep -q "$N8N_CONTAINER"; then
  WEBHOOK_LOGS=$(docker logs "$N8N_CONTAINER" 2>&1 | grep -i webhook | tail -15 || echo "No webhook logs found")
  
  if [ -z "$WEBHOOK_LOGS" ]; then
    echo -e "${YELLOW}⚠️  No webhook-related logs${NC}"
  else
    echo "$WEBHOOK_LOGS"
  fi
else
  echo -e "${RED}❌ Container $N8N_CONTAINER not running${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════
# 6. DIRECT WEBHOOK TEST
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}6️⃣  Direct Webhook Test${NC}"
echo "──────────────────────────────────────────────────"

WEBHOOK_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X POST "${N8N_URL}/webhook/scrape" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://httpbin.org/status/200"}' \
  --max-time 10 2>&1 || echo "ERROR")

HTTP_CODE=$(echo "$WEBHOOK_RESPONSE" | grep HTTP_CODE | cut -d: -f2)
RESPONSE_BODY=$(echo "$WEBHOOK_RESPONSE" | sed '/HTTP_CODE/d')

if [ -z "$HTTP_CODE" ]; then
  HTTP_CODE="000"
fi

echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo -e "Status: ${GREEN}✅ Success${NC}"
else
  echo -e "Status: ${RED}❌ Failed${NC}"
fi

echo "Response preview: ${RESPONSE_BODY:0:200}"
echo ""

# ═══════════════════════════════════════════════════════
# 7. DATABASE WORKFLOW RECORDS
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}7️⃣  Database Workflow Records${NC}"
echo "──────────────────────────────────────────────────"

if docker ps | grep -q "$DB_CONTAINER"; then
  DB_WORKFLOWS=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c \
    "SELECT id, name, active, 'createdAt', 'updatedAt' FROM workflow_entity ORDER BY 'updatedAt' DESC LIMIT 10;" \
    2>&1 || echo "ERROR")
  
  if [ "$DB_WORKFLOWS" = "ERROR" ]; then
    echo -e "${RED}❌ Cannot query database${NC}"
  else
    echo "$DB_WORKFLOWS"
  fi
else
  echo -e "${RED}❌ Container $DB_CONTAINER not running${NC}"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo -e "${GREEN}✅ Diagnostic complete!${NC}"
echo ""
echo "💡 Next steps:"
echo "   1. Check if webhooks show 'active:true' in workflow list"
echo "   2. Verify HTTP 200 in direct webhook test"
echo "   3. Review webhook logs for registration errors"
echo "   4. Run: bash scripts/test-n8n-workflows.sh"
