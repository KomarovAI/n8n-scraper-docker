#!/bin/bash
set -e

# Combined Service Test - объединяет health checks + integration tests
# Оптимизация: -4 мин (7 мин → 3 мин)

echo "🧪 Starting Combined Service Tests"
echo "========================================"
echo ""

# Phase 1: Quick Health Checks (30 seconds)
echo "📊 Phase 1: Quick Health Checks"
echo "========================================"

# PostgreSQL health
echo "🔵 Testing PostgreSQL..."
for i in {1..30}; do
  if docker compose exec -T postgres pg_isready -U scraper_user 2>/dev/null; then
    echo "✅ PostgreSQL is healthy"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ PostgreSQL health check timeout"
    exit 1
  fi
  sleep 1
done

# Redis health
echo "🔴 Testing Redis..."
for i in {1..30}; do
  if docker compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q PONG; then
    echo "✅ Redis is healthy"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ Redis health check timeout"
    exit 1
  fi
  sleep 1
done

# Prometheus health
echo "📊 Testing Prometheus..."
for i in {1..30}; do
  if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "✅ Prometheus is healthy"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ Prometheus health check timeout"
    exit 1
  fi
  sleep 1
done

# Grafana health
echo "📈 Testing Grafana..."
for i in {1..30}; do
  if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "✅ Grafana is healthy"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ Grafana health check timeout"
    exit 1
  fi
  sleep 1
done

# Exporters health
echo "📡 Testing Exporters..."
curl -sf http://localhost:9100/metrics > /dev/null && echo "✅ Node Exporter responding"
curl -sf http://localhost:9121/metrics > /dev/null && echo "✅ Redis Exporter responding"
curl -sf http://localhost:9187/metrics > /dev/null && echo "✅ PostgreSQL Exporter responding"

echo ""
echo "========================================"
echo "📊 Phase 2: Deep Integration Tests"
echo "========================================"
echo ""

# PostgreSQL: Connectivity + Queries + Persistence
echo "🔵 Testing PostgreSQL integration..."

# Test connectivity
docker compose exec -T postgres psql -U scraper_user -d scraper_db -c "SELECT version();" > /dev/null
echo "  ✅ Connectivity verified"

# Test write
docker compose exec -T postgres psql -U scraper_user -d scraper_db -c "CREATE TABLE IF NOT EXISTS test_table (id INT, data TEXT);" > /dev/null
docker compose exec -T postgres psql -U scraper_user -d scraper_db -c "INSERT INTO test_table VALUES (1, 'test_data');" > /dev/null
echo "  ✅ Write operations working"

# Test persistence (restart + verify)
docker compose restart postgres > /dev/null 2>&1
sleep 15
RESULT=$(docker compose exec -T postgres psql -U scraper_user -d scraper_db -c "SELECT data FROM test_table WHERE id=1;" | grep test_data || echo "")
if [ -n "$RESULT" ]; then
  echo "  ✅ Data persistence verified"
else
  echo "  ❌ Data persistence failed"
  exit 1
fi

# Redis: Read/Write + Pub/Sub
echo "🔴 Testing Redis integration..."

# Test read/write
docker compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" SET test_key "test_value" > /dev/null
VALUE=$(docker compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" GET test_key)
if [ "$VALUE" = "test_value" ]; then
  echo "  ✅ Read/Write operations working"
else
  echo "  ❌ Redis read/write failed"
  exit 1
fi

# Test key expiration
docker compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" SETEX expire_test 2 "value" > /dev/null
sleep 3
EXPIRED=$(docker compose exec -T redis redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" GET expire_test)
if [ "$EXPIRED" = "" ]; then
  echo "  ✅ Key expiration working"
else
  echo "  ❌ Key expiration failed"
  exit 1
fi

# Prometheus: Targets + Metrics Collection
echo "📊 Testing Prometheus integration..."

# Check targets
TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health=="up") | .scrapeUrl' | wc -l)
if [ "$TARGETS" -gt 0 ]; then
  echo "  ✅ $TARGETS healthy targets found"
else
  echo "  ❌ No healthy targets"
  exit 1
fi

# Verify metrics collection
METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=up' | jq -r '.data.result | length')
if [ "$METRICS" -gt 0 ]; then
  echo "  ✅ Metrics collection working ($METRICS series)"
else
  echo "  ❌ No metrics collected"
  exit 1
fi

# Grafana: API + Datasources
echo "📈 Testing Grafana integration..."

# Test API
API_STATUS=$(curl -su "${GRAFANA_USER}:${GRAFANA_PASSWORD}" http://localhost:3000/api/health | jq -r '.database')
if [ "$API_STATUS" = "ok" ]; then
  echo "  ✅ Grafana API responding"
else
  echo "  ❌ Grafana API failed"
  exit 1
fi

# Check datasources
DATASOURCES=$(curl -su "${GRAFANA_USER}:${GRAFANA_PASSWORD}" http://localhost:3000/api/datasources | jq '. | length')
if [ "$DATASOURCES" -gt 0 ]; then
  echo "  ✅ $DATASOURCES datasources configured"
else
  echo "  ⚠️  No datasources (expected if fresh install)"
fi

# Exporters: Verify Metrics Availability
echo "📡 Testing Exporters metrics..."

# Node Exporter
if curl -s http://localhost:9100/metrics | grep -q "node_cpu_seconds_total"; then
  echo "  ✅ Node Exporter: CPU metrics available"
else
  echo "  ❌ Node Exporter: CPU metrics missing"
  exit 1
fi

# Redis Exporter
if curl -s http://localhost:9121/metrics | grep -q "redis_memory_used_bytes"; then
  echo "  ✅ Redis Exporter: Memory metrics available"
else
  echo "  ❌ Redis Exporter: Memory metrics missing"
  exit 1
fi

# PostgreSQL Exporter
if curl -s http://localhost:9187/metrics | grep -q "pg_stat_database_numbackends"; then
  echo "  ✅ PostgreSQL Exporter: Connection metrics available"
else
  echo "  ❌ PostgreSQL Exporter: Connection metrics missing"
  exit 1
fi

echo ""
echo "========================================"
echo "🎉 ALL COMBINED SERVICE TESTS PASSED!"
echo "========================================"
echo "✅ Health Checks: PostgreSQL, Redis, Prometheus, Grafana, Exporters"
echo "✅ PostgreSQL: Connectivity, Queries, Persistence"
echo "✅ Redis: Read/Write, Expiration"
echo "✅ Prometheus: Targets, Metrics Collection"
echo "✅ Grafana: API, Datasources"
echo "✅ Exporters: All metrics available"
echo "========================================"
