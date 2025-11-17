#!/bin/bash

set -e

echo "🚀 Deploying N8N Scraper to Kubernetes..."
echo ""

# 🔍 Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found. Please install kubectl first."
    exit 1
fi

# 🔍 Проверка доступа к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster."
    echo "Run: kubectl config view"
    exit 1
fi

# 🔑 Проверка наличия secret.yaml
if [ ! -f "manifests/secret.yaml" ]; then
    echo "⚠️  Warning: manifests/secret.yaml not found!"
    echo "ℹ️  Creating from example..."
    cp manifests/secret.yaml.example manifests/secret.yaml
    echo ""
    echo "📝 Please edit manifests/secret.yaml with your credentials:"
    echo "   vim manifests/secret.yaml"
    echo ""
    read -p "Press Enter after editing secrets..."
fi

# 🌍 Проверка и замена SERVER_IP
if grep -q "YOUR_SERVER_IP" manifests/ingressroute.yaml; then
    echo "⚠️  YOUR_SERVER_IP placeholder found in ingressroute.yaml"
    
    if [ -z "$SERVER_IP" ]; then
        read -p "🌍 Enter your server IP address: " SERVER_IP
    fi
    
    if [ -z "$SERVER_IP" ]; then
        echo "❌ Error: SERVER_IP is required!"
        exit 1
    fi
    
    echo "🔄 Replacing YOUR_SERVER_IP with $SERVER_IP..."
    sed -i.bak "s/YOUR_SERVER_IP/$SERVER_IP/g" manifests/ingressroute.yaml
    echo "✅ Done! (backup saved as ingressroute.yaml.bak)"
fi

echo ""
echo "📦 Applying manifests..."
echo ""

# 1. Namespace (сначала)
echo "➡️  Creating namespace..."
kubectl apply -f manifests/namespace.yaml

# 2. Secrets
echo "➡️  Creating secrets..."
kubectl apply -f manifests/secret.yaml

# 3. Базы данных (до N8N!)
echo "➡️  Deploying PostgreSQL..."
kubectl apply -f manifests/postgresql.yaml

echo "➡️  Deploying Redis..."
kubectl apply -f manifests/redis.yaml

# № Ожидаем готовности PostgreSQL
echo ""
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n n8n-scraper --timeout=120s || true

echo "⏳ Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n n8n-scraper --timeout=60s || true

echo ""

# 4. N8N StatefulSet
echo "➡️  Deploying N8N..."
kubectl apply -f manifests/statefulset.yaml

# 5. Services
echo "➡️  Creating services..."
kubectl apply -f manifests/service.yaml

# 6. NetworkPolicy
echo "➡️  Applying network policies..."
kubectl apply -f manifests/networkpolicy.yaml

# 7. IngressRoute (последним!)
echo "➡️  Creating IngressRoute..."
kubectl apply -f manifests/ingressroute.yaml

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Check status:"
echo "  kubectl get pods -n n8n-scraper"
echo "  kubectl get statefulset -n n8n-scraper"
echo "  kubectl get pvc -n n8n-scraper"
echo ""
echo "📝 View logs:"
echo "  kubectl logs -f n8n-scraper-0 -n n8n-scraper"
echo ""

if [ ! -z "$SERVER_IP" ]; then
    echo "🌐 Access N8N at: https://n8n.$SERVER_IP.nip.io"
else
    echo "🌐 Access N8N at: https://n8n.<YOUR_IP>.nip.io"
fi
echo ""
