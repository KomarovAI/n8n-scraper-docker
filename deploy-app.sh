#!/bin/bash
set -e
# STEP 2: Приложение + ingress
kubectl apply -f manifests/statefulset-n8n.yaml
kubectl rollout status statefulset/n8n -n n8n-scraper
kubectl apply -f manifests/ingressroute.yaml

echo "✅ [step 2] N8N app и ingress запущены!"
