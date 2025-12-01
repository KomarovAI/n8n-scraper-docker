#!/bin/bash
# Setup Persistent n8n on Self-Hosted Runner

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}==========================================="
echo "   PERSISTENT N8N SETUP FOR RUNNER"
echo "===========================================${NC}"
echo ""

# Check docker-compose.persistent.yml
if [ ! -f "docker-compose.persistent.yml" ]; then
  echo -e "${RED}❌ docker-compose.persistent.yml not found!${NC}"
  exit 1
fi

# Create .env.persistent if missing
if [ ! -f ".env.persistent" ]; then
  echo -e "${YELLOW}Creating .env.persistent...${NC}"
  
  ENCRYPTION_KEY=$(openssl rand -hex 32)
  
  cat > .env.persistent << EOF
# Persistent n8n Configuration
# DO NOT COMMIT TO GIT!
POSTGRES_PASSWORD=persistent_secure_password_$(openssl rand -hex 8)
REDIS_PASSWORD=persistent_redis_password_$(openssl rand -hex 8)
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
EOF

  echo -e "${GREEN}✅ .env.persistent created${NC}"
  echo -e "${YELLOW}⚠️  IMPORTANT: Encryption key generated!${NC}"
  echo -e "${YELLOW}   DO NOT CHANGE N8N_ENCRYPTION_KEY after first startup!${NC}"
  echo ""
fi

# Check if already running
if docker ps --filter "name=n8n-persistent" | grep -q "n8n-persistent"; then
  echo -e "${YELLOW}⚠️  n8n-persistent already running!${NC}"
  read -p "Restart? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker compose -f docker-compose.persistent.yml --env-file .env.persistent restart
    echo -e "${GREEN}✅ Restarted${NC}"
  fi
  exit 0
fi

# Start stack
echo -e "${GREEN}Starting persistent n8n stack...${NC}"
docker compose -f docker-compose.persistent.yml --env-file .env.persistent up -d

echo ""
echo -e "${GREEN}Waiting for n8n readiness...${NC}"

for i in {1..120}; do
  if curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
    echo -e "${GREEN}✅ n8n is running${NC}"
    break
  fi
  [ $i -eq 120 ] && echo -e "${RED}❌ Timeout${NC}" && exit 1
  sleep 1
done

for i in {1..60}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz/readiness)
  if [ "$CODE" == "200" ]; then
    echo -e "${GREEN}✅ n8n is fully ready${NC}"
    break
  fi
  [ $i -eq 60 ] && echo -e "${RED}❌ Readiness timeout${NC}" && exit 1
  sleep 2
done

echo ""
echo -e "${GREEN}==========================================="
echo "   ✅ SETUP COMPLETE!"
echo "===========================================${NC}"
echo ""
echo -e "${GREEN}n8n URL:${NC} http://localhost:5678"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open http://localhost:5678 and create owner account"
echo "2. Settings → n8n API → Create API key"
echo "3. Add to GitHub Secrets: gh secret set N8N_API --body 'n8n_api_xxxxx'"
echo "4. Test: curl -H 'X-N8N-API-KEY: key' http://localhost:5678/api/v1/workflows"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "  docker logs n8n-persistent -f"
echo "  docker compose -f docker-compose.persistent.yml restart"
echo "  docker compose -f docker-compose.persistent.yml down"
echo ""