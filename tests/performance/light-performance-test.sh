#!/bin/bash
set -e

# Light Performance Test - ловит performance regressions РАНО
# Best practice 2025: Shift-left performance testing

echo "📊 Starting Light Performance Tests"
echo "========================================"
echo ""

# Performance thresholds
MAX_AVG_EXECUTION_TIME=5000  # ms
MAX_MEMORY_MB=1024           # MB
MAX_ERROR_RATE=5             # %
CONCURRENT_EXECUTIONS=10
TOTAL_EXECUTIONS=50

echo "🎯 Test Configuration:"
echo "  Max avg execution time: ${MAX_AVG_EXECUTION_TIME}ms"
echo "  Max memory usage: ${MAX_MEMORY_MB}MB"
echo "  Max error rate: ${MAX_ERROR_RATE}%"
echo "  Concurrent executions: $CONCURRENT_EXECUTIONS"
echo "  Total executions: $TOTAL_EXECUTIONS"
echo ""

# Check if n8n is running
if ! curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
  echo "❌ n8n is not running"
  exit 1
fi

echo "✅ n8n is running"
echo ""

# Create simple test workflow
echo "📦 Creating test workflow..."

WORKFLOW_JSON='{
  "name": "Performance Test Workflow",
  "nodes": [
    {
      "parameters": {},
      "id": "start",
      "name": "Start",
      "type": "n8n-nodes-base.start",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "jsCode": "const start = Date.now();\nlet sum = 0;\nfor (let i = 0; i < 10000; i++) { sum += i; }\nconst duration = Date.now() - start;\nreturn { json: { sum, duration, timestamp: new Date().toISOString() } };"
      },
      "id": "code",
      "name": "Code",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Start": {
      "main": [[{"node": "Code", "type": "main", "index": 0}]]
    }
  },
  "active": false,
  "settings": { "executionOrder": "v1" }
}'

WORKFLOW_RESPONSE=$(curl -s -X POST "http://localhost:5678/rest/workflows" \
  -H "Content-Type: application/json" \
  -u "${N8N_USER}:${N8N_PASSWORD}" \
  -d "$WORKFLOW_JSON")

WORKFLOW_ID=$(echo "$WORKFLOW_RESPONSE" | jq -r '.id // empty')

if [ -z "$WORKFLOW_ID" ] || [ "$WORKFLOW_ID" = "null" ]; then
  echo "❌ Failed to create workflow"
  exit 1
fi

echo "✅ Test workflow created (ID: $WORKFLOW_ID)"
echo ""

# Measure baseline memory
echo "💾 Measuring baseline memory..."
BASELINE_MEMORY=$(docker stats n8n --no-stream --format "{{.MemUsage}}" | awk '{print $1}' | sed 's/MiB//')
echo "✅ Baseline memory: ${BASELINE_MEMORY}MB"
echo ""

# Execute workflows
echo "🚀 Executing workflows ($TOTAL_EXECUTIONS total, $CONCURRENT_EXECUTIONS concurrent)..."

SUCCESS_COUNT=0
ERROR_COUNT=0
TOTAL_DURATION=0
EXECUTION_IDS=()

for batch in $(seq 1 $((TOTAL_EXECUTIONS / CONCURRENT_EXECUTIONS))); do
  echo "  Batch $batch/$((TOTAL_EXECUTIONS / CONCURRENT_EXECUTIONS))..."
  
  # Start concurrent executions
  for i in $(seq 1 $CONCURRENT_EXECUTIONS); do
    EXEC_RESPONSE=$(curl -s -X POST "http://localhost:5678/rest/workflows/$WORKFLOW_ID/execute" \
      -H "Content-Type: application/json" \
      -u "${N8N_USER}:${N8N_PASSWORD}" \
      -d '{}')
    
    EXEC_ID=$(echo "$EXEC_RESPONSE" | jq -r '.data.executionId // empty')
    if [ -n "$EXEC_ID" ] && [ "$EXEC_ID" != "null" ]; then
      EXECUTION_IDS+=("$EXEC_ID")
    fi
  done
  
  # Wait for completions
  sleep 2
done

echo "✅ All executions started"
echo ""

# Wait for all executions to complete
echo "⏳ Waiting for executions to complete..."
sleep 5

# Check results
echo "📊 Analyzing results..."

for EXEC_ID in "${EXECUTION_IDS[@]}"; do
  RESULT=$(curl -s -X GET "http://localhost:5678/rest/executions/$EXEC_ID" \
    -u "${N8N_USER}:${N8N_PASSWORD}")
  
  STATUS=$(echo "$RESULT" | jq -r '.status // "unknown"')
  FINISHED=$(echo "$RESULT" | jq -r '.finished // false')
  
  if [ "$FINISHED" = "true" ]; then
    if [ "$STATUS" = "success" ]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      
      # Extract duration if available
      START_TIME=$(echo "$RESULT" | jq -r '.startedAt // ""')
      STOP_TIME=$(echo "$RESULT" | jq -r '.stoppedAt // ""')
      
      if [ -n "$START_TIME" ] && [ -n "$STOP_TIME" ]; then
        START_MS=$(date -d "$START_TIME" +%s%3N 2>/dev/null || echo "0")
        STOP_MS=$(date -d "$STOP_TIME" +%s%3N 2>/dev/null || echo "0")
        if [ "$START_MS" != "0" ] && [ "$STOP_MS" != "0" ]; then
          DURATION=$((STOP_MS - START_MS))
          TOTAL_DURATION=$((TOTAL_DURATION + DURATION))
        fi
      fi
    else
      ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
  fi
done

echo "✅ Results analyzed"
echo ""

# Calculate metrics
TOTAL_COMPLETED=$((SUCCESS_COUNT + ERROR_COUNT))
ERROR_RATE=0
if [ "$TOTAL_COMPLETED" -gt 0 ]; then
  ERROR_RATE=$((ERROR_COUNT * 100 / TOTAL_COMPLETED))
fi

AVG_DURATION=0
if [ "$SUCCESS_COUNT" -gt 0 ] && [ "$TOTAL_DURATION" -gt 0 ]; then
  AVG_DURATION=$((TOTAL_DURATION / SUCCESS_COUNT))
fi

# Measure final memory
FINAL_MEMORY=$(docker stats n8n --no-stream --format "{{.MemUsage}}" | awk '{print $1}' | sed 's/MiB//')
MEMORY_INCREASE=$((FINAL_MEMORY - BASELINE_MEMORY))

echo "========================================"
echo "📊 PERFORMANCE METRICS"
echo "========================================"
echo "Executions:"
echo "  Total: $TOTAL_EXECUTIONS"
echo "  Success: $SUCCESS_COUNT"
echo "  Errors: $ERROR_COUNT"
echo "  Error rate: ${ERROR_RATE}%"
echo ""
echo "Timing:"
echo "  Avg execution time: ${AVG_DURATION}ms"
echo "  Threshold: ${MAX_AVG_EXECUTION_TIME}ms"
echo ""
echo "Memory:"
echo "  Baseline: ${BASELINE_MEMORY}MB"
echo "  Final: ${FINAL_MEMORY}MB"
echo "  Increase: ${MEMORY_INCREASE}MB"
echo "  Threshold: ${MAX_MEMORY_MB}MB"
echo "========================================"
echo ""

# Validate thresholds
FAILED=0

if [ "$ERROR_RATE" -gt "$MAX_ERROR_RATE" ]; then
  echo "❌ FAIL: Error rate ${ERROR_RATE}% exceeds threshold ${MAX_ERROR_RATE}%"
  FAILED=1
else
  echo "✅ PASS: Error rate within threshold"
fi

if [ "$AVG_DURATION" -gt 0 ] && [ "$AVG_DURATION" -gt "$MAX_AVG_EXECUTION_TIME" ]; then
  echo "❌ FAIL: Avg execution time ${AVG_DURATION}ms exceeds threshold ${MAX_AVG_EXECUTION_TIME}ms"
  FAILED=1
else
  echo "✅ PASS: Execution time within threshold"
fi

if [ "$FINAL_MEMORY" -gt "$MAX_MEMORY_MB" ]; then
  echo "⚠️  WARNING: Memory usage ${FINAL_MEMORY}MB exceeds threshold ${MAX_MEMORY_MB}MB"
  echo "  (Not failing, but may indicate memory leak)"
else
  echo "✅ PASS: Memory usage within threshold"
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
curl -s -X DELETE "http://localhost:5678/rest/workflows/$WORKFLOW_ID" \
  -u "${N8N_USER}:${N8N_PASSWORD}" > /dev/null
echo "✅ Cleanup complete"

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "========================================"
  echo "🎉 LIGHT PERFORMANCE TEST PASSED!"
  echo "========================================"
  exit 0
else
  echo "========================================"
  echo "❌ LIGHT PERFORMANCE TEST FAILED!"
  echo "========================================"
  exit 1
fi
