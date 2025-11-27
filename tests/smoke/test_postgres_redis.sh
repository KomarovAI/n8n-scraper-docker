#!/bin/bash
# Smoke Test: PostgreSQL + Redis
# Tests database and cache layer connectivity

set -e

echo "🧪 Testing PostgreSQL + Redis connectivity"
echo "============================================"

# Test PostgreSQL
echo "📊 Testing PostgreSQL..."
if docker-compose exec -T postgres pg_isready -U "${POSTGRES_USER:-n8n_user}"; then
    echo "✅ PostgreSQL is ready"
else
    echo "❌ PostgreSQL is not ready"
    exit 1
fi

# Test database connection
echo "🔍 Testing database connection..."
if docker-compose exec -T postgres psql -U "${POSTGRES_USER:-n8n_user}" -c "SELECT 1" > /dev/null 2>&1; then
    echo "✅ Database connection successful"
else
    echo "❌ Database connection failed"
    exit 1
fi

# Test Redis
echo "📦 Testing Redis..."
if docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
    echo "✅ Redis is responding"
else
    echo "❌ Redis is not responding"
    exit 1
fi

# Test Redis set/get
echo "🔍 Testing Redis operations..."
TEST_KEY="test_key_$(date +%s)"
TEST_VALUE="test_value_$(date +%s)"

docker-compose exec -T redis redis-cli SET "$TEST_KEY" "$TEST_VALUE" > /dev/null
RETRIEVED=$(docker-compose exec -T redis redis-cli GET "$TEST_KEY" | tr -d '\r')

if [ "$RETRIEVED" = "$TEST_VALUE" ]; then
    echo "✅ Redis SET/GET operations working"
    docker-compose exec -T redis redis-cli DEL "$TEST_KEY" > /dev/null
else
    echo "❌ Redis SET/GET operations failed"
    exit 1
fi

echo ""
echo "✅ All PostgreSQL + Redis tests passed!"
exit 0
