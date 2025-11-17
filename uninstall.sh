#!/bin/bash

set -e

echo "⚠️  WARNING: This will delete ALL N8N Scraper resources!"
echo "⚠️  This includes: N8N, PostgreSQL, Redis, and all data (PVCs)!"
echo ""
read -p "Are you sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelled."
    exit 0
fi

echo ""
echo "🗑️  Uninstalling N8N Scraper..."
echo ""

# Удаляем в обратном порядке
echo "➡️  Removing IngressRoute..."
kubectl delete -f manifests/ingressroute.yaml --ignore-not-found

echo "➡️  Removing NetworkPolicies..."
kubectl delete -f manifests/networkpolicy.yaml --ignore-not-found

echo "➡️  Removing Services..."
kubectl delete -f manifests/service.yaml --ignore-not-found

echo "➡️  Removing N8N StatefulSet..."
kubectl delete -f manifests/statefulset.yaml --ignore-not-found

echo "➡️  Removing PostgreSQL..."
kubectl delete -f manifests/postgresql.yaml --ignore-not-found

echo "➡️  Removing Redis..."
kubectl delete -f manifests/redis.yaml --ignore-not-found

echo "➡️  Removing Secrets..."
kubectl delete -f manifests/secret.yaml --ignore-not-found

echo ""
echo "⏳ Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app=n8n-scraper -n n8n-scraper --timeout=60s || true
kubectl wait --for=delete pod -l app=postgresql -n n8n-scraper --timeout=60s || true
kubectl wait --for=delete pod -l app=redis -n n8n-scraper --timeout=60s || true

echo ""
echo "💾 Deleting PersistentVolumeClaims (this will DELETE ALL DATA)..."
kubectl delete pvc -n n8n-scraper --all --ignore-not-found

echo ""
echo "➡️  Removing Namespace..."
kubectl delete namespace n8n-scraper --ignore-not-found

echo ""
echo "✅ Uninstall complete!"
echo ""
echo "📊 Verify deletion:"
echo "  kubectl get all -n n8n-scraper"
echo "  kubectl get pvc -n n8n-scraper"
echo ""
