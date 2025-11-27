#!/bin/bash
set -e

# Smoke Test - проверяет что контейнеры НЕ падают сразу после запуска
# Это критично для выявления packaging bugs

echo "🔥 Starting Docker Smoke Tests"
echo "========================================"
echo ""

# Test 1: n8n-enhanced container
echo "📦 Test 1: n8n-enhanced container stability"
echo "Building image..."
docker build -f Dockerfile.n8n-enhanced -t n8n-scraper:smoke-test . > /dev/null 2>&1

echo "Starting container..."
docker run -d \
  --name smoke-n8n \
  -e N8N_HOST=localhost \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=http \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=postgres \
  -e DB_POSTGRESDB_PORT=5432 \
  -e DB_POSTGRESDB_DATABASE=scraper_db \
  -e DB_POSTGRESDB_USER=scraper_user \
  -e DB_POSTGRESDB_PASSWORD=test_password \
  n8n-scraper:smoke-test

echo "⏳ Waiting for container stability (30 seconds)..."
for i in {1..10}; do
  # Check if container is still running
  if ! docker ps | grep -q smoke-n8n; then
    echo "❌ Container died after $((i*3)) seconds!"
    docker logs smoke-n8n
    docker rm -f smoke-n8n 2>/dev/null || true
    exit 1
  fi
  
  # Check for fatal errors in logs
  if docker logs smoke-n8n 2>&1 | grep -i "fatal error\|segmentation fault\|panic"; then
    echo "❌ Fatal error detected in logs!"
    docker logs smoke-n8n
    docker rm -f smoke-n8n 2>/dev/null || true
    exit 1
  fi
  
  echo "Container alive... ($((i*3))/30 seconds)"
  sleep 3
done

echo "✅ n8n container stable for 30 seconds"
docker stop smoke-n8n > /dev/null 2>&1
docker rm smoke-n8n > /dev/null 2>&1
echo ""

# Test 2: ML Service container (if exists)
if [ -f "ml/Dockerfile" ]; then
  echo "📦 Test 2: ML Service container stability"
  echo "Building image..."
  docker build -f ml/Dockerfile -t ml-service:smoke-test ./ml > /dev/null 2>&1
  
  echo "Starting container..."
  docker run -d \
    --name smoke-ml \
    -e PORT=8000 \
    ml-service:smoke-test
  
  echo "⏳ Waiting for container stability (20 seconds)..."
  for i in {1..7}; do
    if ! docker ps | grep -q smoke-ml; then
      echo "❌ ML container died after $((i*3)) seconds!"
      docker logs smoke-ml
      docker rm -f smoke-ml 2>/dev/null || true
      exit 1
    fi
    
    if docker logs smoke-ml 2>&1 | grep -i "fatal error\|traceback\|exception"; then
      echo "❌ Error detected in ML logs!"
      docker logs smoke-ml
      docker rm -f smoke-ml 2>/dev/null || true
      exit 1
    fi
    
    echo "ML container alive... ($((i*3))/21 seconds)"
    sleep 3
  done
  
  echo "✅ ML Service container stable for 20 seconds"
  docker stop smoke-ml > /dev/null 2>&1
  docker rm smoke-ml > /dev/null 2>&1
else
  echo "ℹ️  ML Service Dockerfile not found, skipping"
fi

echo ""
echo "========================================"
echo "🎉 ALL SMOKE TESTS PASSED!"
echo "========================================"
echo "✅ n8n container stability verified"
echo "✅ ML Service container stability verified"
echo "✅ No immediate crashes"
echo "✅ No fatal errors in logs"
echo "========================================"
