#!/bin/bash

set -e

echo "⚠️  WARNING: This will delete all N8N Scraper resources!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo "🗑️  Uninstalling N8N Scraper..."

kubectl delete -f manifests/ingressroute.yaml --ignore-not-found
kubectl delete -f manifests/networkpolicy.yaml --ignore-not-found
kubectl delete -f manifests/service.yaml --ignore-not-found
kubectl delete -f manifests/statefulset.yaml --ignore-not-found
kubectl delete -f manifests/secret.yaml --ignore-not-found
kubectl delete namespace n8n-scraper --ignore-not-found

echo "✅ Uninstall complete!"
