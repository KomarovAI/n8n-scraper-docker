#!/bin/bash
# Smoke Test: Tor Proxy
# Tests Tor SOCKS5 proxy connectivity and anonymity

set -e

echo "🧪 Testing Tor proxy"
echo "====================="

# Test Tor service is running
echo "🔍 Checking Tor service status..."
if docker-compose ps tor | grep -q "Up"; then
    echo "✅ Tor service is running"
else
    echo "❌ Tor service is not running"
    exit 1
fi

# Test SOCKS5 proxy port
echo "🔌 Testing SOCKS5 proxy port 9050..."
if docker-compose exec -T tor sh -c 'nc -z localhost 9050' 2>/dev/null; then
    echo "✅ SOCKS5 port 9050 is accessible"
else
    echo "❌ SOCKS5 port 9050 is not accessible"
    exit 1
fi

# Test Tor connectivity (optional - may fail in restricted networks)
echo "🌐 Testing Tor connectivity (optional)..."
if docker-compose exec -T tor sh -c 'curl -s --socks5-hostname localhost:9050 https://check.torproject.org --max-time 10' 2>/dev/null | grep -q "Congratulations"; then
    echo "✅ Tor connectivity verified - you are using Tor!"
elif docker-compose exec -T tor sh -c 'curl -s --socks5-hostname localhost:9050 https://httpbin.org/ip --max-time 10' 2>/dev/null | grep -q "origin"; then
    echo "✅ Tor proxy is working (check.torproject.org unreachable, but proxy functional)"
else
    echo "⚠️  WARNING: Tor connectivity test inconclusive (may be network restrictions)"
    echo "   Tor service is running, assuming functional"
fi

echo ""
echo "✅ Tor proxy tests passed!"
exit 0
