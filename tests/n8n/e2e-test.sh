#!/bin/bash
set -e

# n8n E2E Test Script
# Tests workflow import, execution, and validation

N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD}"
WORKFLOW_FILE="${WORKFLOW_FILE:-tests/n8n/test-workflow.json}"

echo "🧪 Starting n8n E2E Tests"
echo "========================================"
echo "n8n URL: $N8N_URL"
echo "User: $N8N_USER"
echo "Workflow: $WORKFLOW_FILE"
echo "========================================"
echo ""

# Wait for n8n to be ready
echo "⏳ Waiting for n8n to be ready..."
for i in {1..60}; do
  if curl -s -f "$N8N_URL/healthz" > /dev/null 2>&1; then
    echo "✅ n8n is ready"
    break
  fi
  if [ $i -eq 60 ]; then
    echo "❌ n8n failed to start after 60 seconds"
    exit 1
  fi
  echo "Waiting... ($i/60)"
  sleep 2
done
echo ""

# Get n8n API credentials
echo "🔐 Testing authentication..."
AUTH_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$N8N_USER\",\"password\":\"$N8N_PASSWORD\"}")

if echo "$AUTH_RESPONSE" | grep -q "error"; then
  echo "❌ Authentication failed"
  echo "Response: $AUTH_RESPONSE"
  exit 1
fi

echo "✅ Authentication successful"
echo ""

# Import workflow
echo "📥 Importing test workflow..."
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "❌ Workflow file not found: $WORKFLOW_FILE"
  exit 1
fi

WORKFLOW_DATA=$(cat "$WORKFLOW_FILE")
IMPORT_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d "$WORKFLOW_DATA")

WORKFLOW_ID=$(echo "$IMPORT_RESPONSE" | jq -r '.id // empty')

if [ -z "$WORKFLOW_ID" ] || [ "$WORKFLOW_ID" = "null" ]; then
  echo "❌ Failed to import workflow"
  echo "Response: $IMPORT_RESPONSE"
  exit 1
fi

echo "✅ Workflow imported successfully"
echo "Workflow ID: $WORKFLOW_ID"
echo ""

# Execute workflow
echo "▶️  Executing workflow..."
EXECUTE_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows/$WORKFLOW_ID/execute" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d '{}')

EXECUTION_ID=$(echo "$EXECUTE_RESPONSE" | jq -r '.data.executionId // empty')

if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" = "null" ]; then
  echo "❌ Failed to execute workflow"
  echo "Response: $EXECUTE_RESPONSE"
  exit 1
fi

echo "✅ Workflow execution started"
echo "Execution ID: $EXECUTION_ID"
echo ""

# Wait for execution to complete
echo "⏳ Waiting for execution to complete..."
for i in {1..30}; do
  EXECUTION_STATUS=$(curl -s -X GET "$N8N_URL/rest/executions/$EXECUTION_ID" \
    -u "$N8N_USER:$N8N_PASSWORD" | jq -r '.finished // false')
  
  if [ "$EXECUTION_STATUS" = "true" ]; then
    echo "✅ Execution completed"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "❌ Execution timeout after 60 seconds"
    exit 1
  fi
  
  echo "Waiting for completion... ($i/30)"
  sleep 2
done
echo ""

# Get execution result
echo "📊 Validating execution result..."
EXECUTION_RESULT=$(curl -s -X GET "$N8N_URL/rest/executions/$EXECUTION_ID" \
  -u "$N8N_USER:$N8N_PASSWORD")

STATUS=$(echo "$EXECUTION_RESULT" | jq -r '.status // "unknown"')
ERROR=$(echo "$EXECUTION_RESULT" | jq -r '.data.resultData.error // empty')

if [ "$STATUS" != "success" ]; then
  echo "❌ Workflow execution failed"
  echo "Status: $STATUS"
  echo "Error: $ERROR"
  exit 1
fi

echo "✅ Workflow execution successful"
echo "Status: $STATUS"
echo ""

# Validate output data
echo "🔍 Validating output data..."
OUTPUT_DATA=$(echo "$EXECUTION_RESULT" | jq -r '.data.resultData.runData.Validate[0].data.main[0][0].json')

if echo "$OUTPUT_DATA" | jq -e '.status == "success"' > /dev/null; then
  echo "✅ Output data validation passed"
  echo "Output: $OUTPUT_DATA"
else
  echo "❌ Output data validation failed"
  exit 1
fi
echo ""

# Cleanup: Delete test workflow
echo "🧹 Cleaning up test workflow..."
DELETE_RESPONSE=$(curl -s -X DELETE "$N8N_URL/rest/workflows/$WORKFLOW_ID" \
  -u "$N8N_USER:$N8N_PASSWORD")

echo "✅ Test workflow deleted"
echo ""

# Final summary
echo "========================================"
echo "🎉 ALL E2E TESTS PASSED!"
echo "========================================"
echo "✅ n8n authentication"
echo "✅ Workflow import"
echo "✅ Workflow execution"
echo "✅ Output validation"
echo "✅ Cleanup"
echo "========================================"
