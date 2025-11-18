#!/bin/bash
set -e
# STEP 1: Базы и кэш
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/secret-n8n-creds.yaml
kubectl apply -f manifests/statefulset-pg.yaml
kubectl apply -f manifests/statefulset-redis.yaml
kubectl rollout status statefulset/postgresql -n n8n-scraper
kubectl rollout status statefulset/redis -n n8n-scraper

echo "✅ [step 1] PostgreSQL/Redis готовы. Переходим к app."
