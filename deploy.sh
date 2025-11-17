#!/bin/bash

set -e

echo "🚀 Deploying N8N Scraper to Kubernetes..."

# Apply manifests
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/secret.yaml  # Make sure you created this from secret.yaml.example
kubectl apply -f manifests/statefulset.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/networkpolicy.yaml
kubectl apply -f manifests/ingressroute.yaml

echo "✅ Deployment complete!"
echo ""
echo "Check status:"
echo "  kubectl get pods -n n8n-scraper"
echo "  kubectl get svc -n n8n-scraper"
echo ""
echo "Access N8N at: https://n8n.${SERVER_IP}.nip.io"
