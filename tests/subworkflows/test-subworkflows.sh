#!/bin/bash
set -e

# n8n Subworkflow Testing Script
# Tests Execute Workflow node and data passing

N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD}"
CHILD_WORKFLOW="${CHILD_WORKFLOW:-tests/subworkflows/child-workflow.json}"
PARENT_WORKFLOW="${PARENT_WORKFLOW:-tests/subworkflows/parent-workflow.json}"

echo "🔗 Starting n8n Subworkflow Tests"
echo "========================================"
echo "n8n URL: $N8N_URL"
echo "Child workflow: $CHILD_WORKFLOW"
echo "Parent workflow: $PARENT_WORKFLOW"
echo "========================================"
echo ""

# Step 1: Import child workflow
echo "📥 Importing child workflow..."
CHILD_DATA=$(cat "$CHILD_WORKFLOW")
CHILD_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d "$CHILD_DATA")

CHILD_ID=$(echo "$CHILD_RESPONSE" | jq -r '.id // empty')

if [ -z "$CHILD_ID" ] || [ "$CHILD_ID" = "null" ]; then
  echo "❌ Failed to import child workflow"
  exit 1
fi

echo "✅ Child workflow imported"
echo "Child ID: $CHILD_ID"
echo ""

# Step 2: Import parent workflow and inject child ID
echo "📥 Importing parent workflow..."
PARENT_DATA=$(cat "$PARENT_WORKFLOW" | sed "s/CHILD_WORKFLOW_ID_PLACEHOLDER/$CHILD_ID/g")
PARENT_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d "$PARENT_DATA")

PARENT_ID=$(echo "$PARENT_RESPONSE" | jq -r '.id // empty')

if [ -z "$PARENT_ID" ] || [ "$PARENT_ID" = "null" ]; then
  echo "❌ Failed to import parent workflow"
  exit 1
fi

echo "✅ Parent workflow imported"
echo "Parent ID: $PARENT_ID"
echo ""

# Step 3: Execute parent workflow (should call child)
echo "▶️  Executing parent workflow..."
EXECUTE_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows/$PARENT_ID/execute" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d '{}')

EXECUTION_ID=$(echo "$EXECUTE_RESPONSE" | jq -r '.data.executionId // empty')

if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" = "null" ]; then
  echo "❌ Failed to execute parent workflow"
  exit 1
fi

echo "✅ Parent workflow execution started"
echo "Execution ID: $EXECUTION_ID"
echo ""

# Step 4: Wait for execution to complete
echo "⏳ Waiting for execution to complete..."
for i in {1..30}; do
  EXECUTION_RESULT=$(curl -s -X GET "$N8N_URL/rest/executions/$EXECUTION_ID" \
    -u "$N8N_USER:$N8N_PASSWORD")
  
  FINISHED=$(echo "$EXECUTION_RESULT" | jq -r '.finished // false')
  
  if [ "$FINISHED" = "true" ]; then
    echo "✅ Execution completed"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "❌ Execution timeout"
    exit 1
  fi
  
  echo "Waiting... ($i/30)"
  sleep 2
done
echo ""

# Step 5: Validate execution status
echo "📊 Validating execution result..."
STATUS=$(echo "$EXECUTION_RESULT" | jq -r '.status // "unknown"')

if [ "$STATUS" != "success" ]; then
  echo "❌ Execution failed"
  echo "Status: $STATUS"
  exit 1
fi

echo "✅ Execution successful"
echo ""

# Step 6: Validate child workflow was called
echo "🔍 Validating child workflow execution..."
CHILD_RESULT=$(echo "$EXECUTION_RESULT" | jq -r '.data.resultData.runData."Execute Child Workflow"[0].data.main[0][0].json // empty')

if [ -z "$CHILD_RESULT" ] || [ "$CHILD_RESULT" = "null" ]; then
  echo "❌ Child workflow was not executed"
  exit 1
fi

echo "✅ Child workflow executed"
echo "Child result: $CHILD_RESULT"
echo ""

# Step 7: Validate calculations
echo "🧮 Validating calculations..."
SUM=$(echo "$CHILD_RESULT" | jq -r '.sum // 0')
PRODUCT=$(echo "$CHILD_RESULT" | jq -r '.product // 0')
DIFFERENCE=$(echo "$CHILD_RESULT" | jq -r '.difference // 0')

if [ "$SUM" != "15" ]; then
  echo "❌ Sum incorrect: expected 15, got $SUM"
  exit 1
fi

if [ "$PRODUCT" != "50" ]; then
  echo "❌ Product incorrect: expected 50, got $PRODUCT"
  exit 1
fi

if [ "$DIFFERENCE" != "5" ]; then
  echo "❌ Difference incorrect: expected 5, got $DIFFERENCE"
  exit 1
fi

echo "✅ All calculations correct"
echo "  Sum: $SUM"
echo "  Product: $PRODUCT"
echo "  Difference: $DIFFERENCE"
echo ""

# Step 8: Validate parent result
echo "🔍 Validating parent workflow output..."
PARENT_RESULT=$(echo "$EXECUTION_RESULT" | jq -r '.data.resultData.runData."Validate Result"[0].data.main[0][0].json // empty')

if echo "$PARENT_RESULT" | jq -e '.status == "success"' > /dev/null; then
  echo "✅ Parent workflow validation passed"
else
  echo "❌ Parent workflow validation failed"
  exit 1
fi
echo ""

# Cleanup
echo "🧹 Cleaning up workflows..."
curl -s -X DELETE "$N8N_URL/rest/workflows/$PARENT_ID" \
  -u "$N8N_USER:$N8N_PASSWORD" > /dev/null

curl -s -X DELETE "$N8N_URL/rest/workflows/$CHILD_ID" \
  -u "$N8N_USER:$N8N_PASSWORD" > /dev/null

echo "✅ Workflows cleaned up"
echo ""

# Final summary
echo "========================================"
echo "🎉 ALL SUBWORKFLOW TESTS PASSED!"
echo "========================================"
echo "✅ Child workflow import"
echo "✅ Parent workflow import"
echo "✅ Child ID injection"
echo "✅ Parent execution"
echo "✅ Child workflow called"
echo "✅ Data passing verified"
echo "✅ Calculations validated"
echo "✅ Cleanup"
echo "========================================"
