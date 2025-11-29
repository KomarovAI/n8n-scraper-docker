# ROOT CAUSE: CI Used Wrong Docker Image

**Date**: 2025-11-29
**Status**: RESOLVED

## TL;DR

CI workflow **built** `n8n-enhanced:test` but **ran** `n8nio/n8n:latest` from Docker Hub.

**Solution**: Created `docker-compose.ci.yml` override to force usage of built image.

## Evidence from Logs

### What Was Built:
```
Build image (fast cache)
file: ./Dockerfile.n8n-enhanced
tags: n8n-enhanced:test
DONE
```

### What Was Run:
```
Start services
docker compose up -d n8n
n8n Pulling              <- WHY PULLING?
46dee94887a9 Pulling fs layer
157.9MB download         <- Standard n8n from Docker Hub
```

## Why It Failed

Standard `n8nio/n8n:latest` image:
- Lacks custom initialization scripts
- Different endpoint registration behavior  
- `/rest/me` endpoint not available after owner setup

Enhanced `n8n-enhanced:test` image:
- Custom nodes and scripts
- Proper initialization
- All endpoints work correctly

## The Fix

Created `docker-compose.ci.yml`:
```yaml
services:
  n8n:
    image: n8n-enhanced:test  # Override
```

Updated workflow:
```bash
docker compose -f docker-compose.yml -f docker-compose.ci.yml up -d n8n
```

## Expected Results

Before: 30+ minutes, 404 errors  
After: 2-3 minutes, all tests pass

## Key Learning

Docker Compose uses `image:` from docker-compose.yml unless explicitly overridden.
Always verify you're running the image you built!