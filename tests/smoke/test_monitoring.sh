#!/bin/bash
# Smoke Test: Monitoring Stack (Prometheus + Grafana)
# Tests metrics collection and visualization services

set -e

echo "🧪 Testing Monitoring Stack"
echo "=============================="

# Test Prometheus
echo "📊 Testing Prometheus..."
if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus is not accessible"
    exit 1
fi

# Test Prometheus API
echo "🔍 Testing Prometheus API..."
if curl -sf http://localhost:9090/api/v1/query?query=up > /dev/null 2>&1; then
    echo "✅ Prometheus API is responding"
else
    echo "❌ Prometheus API is not responding"
    exit 1
fi

# Test Grafana
echo "📊 Testing Grafana..."
if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana is not accessible"
    exit 1
fi

# Test Grafana login page
echo "🔑 Testing Grafana web interface..."
if curl -sf http://localhost:3000 | grep -q "Grafana"; then
    echo "✅ Grafana web interface is accessible"
else
    echo "❌ Grafana web interface is not responding"
    exit 1
fi

# Test Prometheus targets (optional)
echo "🎯 Testing Prometheus targets..."
TARGETS=$(curl -sf http://localhost:9090/api/v1/targets 2>/dev/null | grep -o '"health":"up"' | wc -l || echo "0")
if [ "$TARGETS" -gt 0 ]; then
    echo "✅ Prometheus has $TARGETS active targets"
else
    echo "⚠️  WARNING: No active targets yet (services may still be starting)"
fi

echo ""
echo "✅ All monitoring stack tests passed!"
exit 0
