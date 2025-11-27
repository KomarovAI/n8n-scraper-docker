#!/bin/bash
set -e

# n8n Webhook Testing Script
# Tests webhook endpoint functionality

N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD}"
WEBHOOK_WORKFLOW="${WEBHOOK_WORKFLOW:-tests/webhooks/test-webhook.json}"
SAMPLE_PAYLOAD="${SAMPLE_PAYLOAD:-tests/webhooks/sample-payload.json}"

echo "🔗 Starting n8n Webhook Tests"
echo "========================================"
echo "n8n URL: $N8N_URL"
echo "Webhook workflow: $WEBHOOK_WORKFLOW"
echo "Sample payload: $SAMPLE_PAYLOAD"
echo "========================================"
echo ""

# Import webhook workflow
echo "📥 Importing webhook workflow..."
WORKFLOW_DATA=$(cat "$WEBHOOK_WORKFLOW")
IMPORT_RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d "$WORKFLOW_DATA")

WORKFLOW_ID=$(echo "$IMPORT_RESPONSE" | jq -r '.id // empty')

if [ -z "$WORKFLOW_ID" ] || [ "$WORKFLOW_ID" = "null" ]; then
  echo "❌ Failed to import webhook workflow"
  echo "Response: $IMPORT_RESPONSE"
  exit 1
fi

echo "✅ Webhook workflow imported"
echo "Workflow ID: $WORKFLOW_ID"
echo ""

# Activate workflow
echo "▶️  Activating webhook workflow..."
ACTIVATE_RESPONSE=$(curl -s -X PATCH "$N8N_URL/rest/workflows/$WORKFLOW_ID" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d '{"active": true}')

IS_ACTIVE=$(echo "$ACTIVATE_RESPONSE" | jq -r '.active // false')

if [ "$IS_ACTIVE" != "true" ]; then
  echo "❌ Failed to activate workflow"
  echo "Response: $ACTIVATE_RESPONSE"
  exit 1
fi

echo "✅ Webhook workflow activated"
echo ""

# Get webhook URL
echo "🔍 Getting webhook URL..."
WEBHOOK_PATH=$(echo "$WORKFLOW_DATA" | jq -r '.nodes[] | select(.type=="n8n-nodes-base.webhook") | .parameters.path')
WEBHOOK_URL="$N8N_URL/webhook/$WEBHOOK_PATH"

echo "✅ Webhook URL: $WEBHOOK_URL"
echo ""

# Wait for webhook to be registered
echo "⏳ Waiting for webhook registration..."
sleep 5

# Test webhook endpoint
echo "📨 Sending test payload to webhook..."
PAYLOAD_DATA=$(cat "$SAMPLE_PAYLOAD")
WEBHOOK_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD_DATA")

if [ -z "$WEBHOOK_RESPONSE" ]; then
  echo "❌ No response from webhook"
  exit 1
fi

echo "✅ Webhook responded"
echo "Response: $WEBHOOK_RESPONSE"
echo ""

# Validate webhook response
echo "✅ Validating webhook response..."
STATUS=$(echo "$WEBHOOK_RESPONSE" | jq -r '.status // empty')

if [ "$STATUS" != "success" ]; then
  echo "❌ Webhook response invalid"
  echo "Expected status: success"
  echo "Got: $STATUS"
  exit 1
fi

echo "✅ Webhook response valid"
echo ""

# Check received data
RECEIVED=$(echo "$WEBHOOK_RESPONSE" | jq -r '.receivedData // empty')

if [ -z "$RECEIVED" ] || [ "$RECEIVED" = "null" ]; then
  echo "❌ Webhook did not receive payload"
  exit 1
fi

echo "✅ Webhook received payload correctly"
echo ""

# Deactivate workflow
echo "⏸️  Deactivating webhook workflow..."
curl -s -X PATCH "$N8N_URL/rest/workflows/$WORKFLOW_ID" \
  -H "Content-Type: application/json" \
  -u "$N8N_USER:$N8N_PASSWORD" \
  -d '{"active": false}' > /dev/null

echo "✅ Workflow deactivated"
echo ""

# Cleanup: Delete webhook workflow
echo "🧹 Cleaning up webhook workflow..."
curl -s -X DELETE "$N8N_URL/rest/workflows/$WORKFLOW_ID" \
  -u "$N8N_USER:$N8N_PASSWORD" > /dev/null

echo "✅ Webhook workflow deleted"
echo ""

# Final summary
echo "========================================"
echo "🎉 ALL WEBHOOK TESTS PASSED!"
echo "========================================"
echo "✅ Webhook workflow import"
echo "✅ Webhook activation"
echo "✅ Webhook endpoint accessible"
echo "✅ Payload received correctly"
echo "✅ Response validation"
echo "✅ Cleanup"
echo "========================================"
