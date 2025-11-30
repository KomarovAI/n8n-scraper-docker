#!/bin/bash
# Automated n8n Workflow Testing for CI/CD
# Tests scraper workflows via n8n webhook API WITHOUT authentication
# Fixed: webhook uses authentication: "none" in workflow definition

set -euo pipefail  # CRITICAL: -o pipefail ensures pipe failures are caught

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 n8n Workflow Testing Suite"
echo "═══════════════════════════════════════"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin@example.com}"
N8N_PASSWORD="${N8N_PASSWORD}"
WEBHOOK_PATH="${WEBHOOK_PATH:-/webhook/scrape}"
TIMEOUT="${TEST_TIMEOUT:-30}"

if [ -z "$N8N_PASSWORD" ]; then
  echo -e "${RED}❌ N8N_PASSWORD not set!${NC}"
  exit 1
fi

# Test URLs
TEST_URLS=(
  "https://example.com"
  "https://httpbin.org/html"
  "https://quotes.toscrape.com"
)

# Test counter
PASSED=0
FAILED=0
TOTAL=0

# Results array
RESULTS=()

echo "📊 Configuration:"
echo "   n8n URL: $N8N_URL"
echo "   n8n User: $N8N_USER"
echo "   Password length: ${#N8N_PASSWORD} chars"
echo "   Webhook: $WEBHOOK_PATH"
echo "   Timeout: ${TIMEOUT}s"
echo "   Test URLs: ${#TEST_URLS[@]}"
echo ""

# Check if n8n is accessible
echo "🔍 Checking n8n availability..."
if ! curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1 && \
   ! curl -sf "${N8N_URL}" > /dev/null 2>&1; then
  echo -e "${RED}❌ n8n is not accessible at $N8N_URL${NC}"
  echo "Please ensure n8n is running:"
  echo "  docker-compose up -d n8n"
  exit 1
fi
echo -e "${GREEN}✅ n8n is accessible${NC}"
echo ""

echo "ℹ️  Note: Webhook authentication is set to 'none' in workflow"
echo "   Testing WITHOUT Basic Authentication"
echo ""

# ══════════════════════════════════════════════════════════════════
# PREFLIGHT CHECK: WEBHOOK READINESS VERIFICATION
# FIXED: Webhooks in n8n need time to initialize routing after activation
# Testing without authentication as workflow uses authentication: "none"
# ══════════════════════════════════════════════════════════════════

echo "🔍 Pre-flight check: verifying webhook readiness..."
echo "──────────────────────────────────────────────────────────────────"

PREFLIGHT_URL="https://httpbin.org/html"
PREFLIGHT_RETRIES=10  # Увеличено с 3 до 10
PREFLIGHT_DELAY=5      # Увеличено с 3 до 5 секунд
PREFLIGHT_SUCCESS=false

for ((i=1; i<=PREFLIGHT_RETRIES; i++)); do
  echo "   Attempt $i/$PREFLIGHT_RETRIES: Testing webhook endpoint (waiting ${PREFLIGHT_DELAY}s between attempts)..."
  
  # Тестируем БЕЗ Basic Auth, как настроен webhook
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "${N8N_URL}${WEBHOOK_PATH}" \
    -d "{\"url\": \"$PREFLIGHT_URL\"}" \
    --max-time 15 2>&1 || echo "000")
  
  echo "   HTTP Status Code: $HTTP_CODE"
  
  # Успех если получили 200-299 или даже 404 (значит endpoint существует)
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    # Теперь проверим что ответ валидный
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      "${N8N_URL}${WEBHOOK_PATH}" \
      -d "{\"url\": \"$PREFLIGHT_URL\"}" \
      --max-time 15 2>&1 || echo "CONNECTION_ERROR")
    
    # Проверяем что НЕ получили ошибку и есть валидный JSON
    if [ "$RESPONSE" != "CONNECTION_ERROR" ] && \
       ! echo "$RESPONSE" | grep -qi "Error in workflow" && \
       ! echo "$RESPONSE" | grep -qi "Workflow.*not found" && \
       ! echo "$RESPONSE" | grep -qi "Could not find" && \
       (echo "$RESPONSE" | grep -qE '"success":|"data":|"content":|"title":'); then
      PREFLIGHT_SUCCESS=true
      echo -e "   ${GREEN}✅ Webhook is responding correctly and ready!${NC}"
      echo "   Response preview: ${RESPONSE:0:150}..."
      break
    else
      echo -e "   ${YELLOW}⏳ Webhook responded but workflow not ready yet...${NC}"
      echo "   Response: ${RESPONSE:0:200}"
    fi
  else
    echo -e "   ${YELLOW}⏳ Webhook endpoint not ready (HTTP $HTTP_CODE)...${NC}"
  fi
  
  if [ $i -lt $PREFLIGHT_RETRIES ]; then
    echo -e "   ${YELLOW}⏳ Waiting ${PREFLIGHT_DELAY} seconds before retry...${NC}"
    sleep $PREFLIGHT_DELAY
  fi
done

if [ "$PREFLIGHT_SUCCESS" = false ]; then
  echo -e "${RED}❌ ERROR: Webhook failed to initialize after $PREFLIGHT_RETRIES attempts ($(($PREFLIGHT_RETRIES * $PREFLIGHT_DELAY))s total)${NC}"
  echo ""
  echo "💡 Debug checklist:"
  echo "   1. Check if workflows are ACTIVE: docker-compose exec n8n n8n list:workflow"
  echo "   2. Check n8n logs: docker-compose logs --tail=100 n8n"
  echo "   3. Verify webhook path matches workflow: $WEBHOOK_PATH"
  echo "   4. Test manually: curl -X POST ${N8N_URL}${WEBHOOK_PATH} -H 'Content-Type: application/json' -d '{\"url\":\"https://example.com\"}'"
  echo "   5. Check webhook registration in logs: docker-compose logs n8n | grep -i webhook"
  exit 1
fi

echo ""

# Function to test URL
test_url() {
  local url=$1
  local start_time=$(date +%s)
  
  TOTAL=$((TOTAL + 1))
  echo -n "[Test $TOTAL/${#TEST_URLS[@]}] Testing: $url ... "
  
  # Execute scraper workflow via webhook WITHOUT Basic Auth
  RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    "${N8N_URL}${WEBHOOK_PATH}" \
    -d "{\"url\": \"$url\", \"options\": {\"timeout\": 10000}}" \
    --max-time "$TIMEOUT" \
    2>&1 || echo "REQUEST_FAILED")
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Check response
  if [ "$RESPONSE" = "REQUEST_FAILED" ]; then
    echo -e "${RED}❌ FAILED${NC} (timeout/connection error) [${duration}s]"
    FAILED=$((FAILED + 1))
    RESULTS+=("{ \"url\": \"$url\", \"status\": \"failed\", \"reason\": \"timeout\", \"duration\": $duration }")
    return 1
  fi
  
  # Check if response contains success indicator
  if echo "$RESPONSE" | grep -qE '"success":\s*true|"data":|"content":|"title":|<html'; then
    echo -e "${GREEN}✅ PASSED${NC} [${duration}s]"
    PASSED=$((PASSED + 1))
    
    # Extract content length if available
    CONTENT_LEN=$(echo "$RESPONSE" | grep -oP '"content_length":\s*\K[0-9]+' || echo 0)
    RESULTS+=("{ \"url\": \"$url\", \"status\": \"success\", \"duration\": $duration, \"content_length\": $CONTENT_LEN }")
  else
    echo -e "${RED}❌ FAILED${NC} (no valid response) [${duration}s]"
    echo "   Response preview: ${RESPONSE:0:200}..."
    FAILED=$((FAILED + 1))
    RESULTS+=("{ \"url\": \"$url\", \"status\": \"failed\", \"reason\": \"invalid_response\", \"duration\": $duration }")
    return 1
  fi
  
  sleep 2
}

# Run tests
echo "🧪 Running workflow tests..."
echo "───────────────────────────────────────"
for url in "${TEST_URLS[@]}"; do
  test_url "$url" || true
done

# Calculate success rate
if [ $TOTAL -gt 0 ]; then
  SUCCESS_RATE=$((PASSED * 100 / TOTAL))
else
  SUCCESS_RATE=0
fi

# Summary
echo ""
echo "═══════════════════════════════════════"
echo "📊 Test Results Summary"
echo "═══════════════════════════════════════"
echo "  Total Tests:  $TOTAL"
echo -e "  Passed:       ${GREEN}$PASSED${NC}"
echo -e "  Failed:       ${RED}$FAILED${NC}"
echo -e "  Success Rate: ${SUCCESS_RATE}%"
echo ""

# Generate JSON report
REPORT_FILE="${REPORT_FILE:-n8n-workflow-test-results.json}"

# Build results array
RESULTS_JSON="["
for i in "${!RESULTS[@]}"; do
  RESULTS_JSON+="${RESULTS[$i]}"
  [ $i -lt $((${#RESULTS[@]} - 1)) ] && RESULTS_JSON+=","
done
RESULTS_JSON+="]"

# Generate report
cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "n8n_url": "$N8N_URL",
  "webhook_path": "$WEBHOOK_PATH",
  "authentication": "none",
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "success_rate": $SUCCESS_RATE
  },
  "results": $RESULTS_JSON
}
EOF

echo "📝 Report saved: $REPORT_FILE"
echo ""

# Exit code
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}🎉 All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}⚠️  Some tests failed!${NC}"
  echo ""
  echo "💡 Debug tips:"
  echo "   1. Check n8n logs: docker-compose logs n8n"
  echo "   2. Verify workflows are active in n8n UI"
  echo "   3. Check webhook path: ${N8N_URL}${WEBHOOK_PATH}"
  echo "   4. Test manually: curl -X POST ${N8N_URL}${WEBHOOK_PATH} -H 'Content-Type: application/json' -d '{\"url\":\"https://example.com\"}'"
  echo "   5. Check webhook uses authentication='none': cat workflows/workflow-scraper-main.json | grep authentication"
  exit 1
fi