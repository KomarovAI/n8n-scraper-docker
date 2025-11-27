#!/bin/bash
# n8n Scraper Docker - Automated Setup Script
# Automates first-time installation and configuration

set -e  # Exit on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🚀 n8n Scraper Docker - Automated Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/8]${NC} Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found!${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found!${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo -e "${RED}❌ OpenSSL not found!${NC}"
    echo "Please install OpenSSL to generate secure passwords"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

# Create .env if missing
echo -e "${YELLOW}[2/8]${NC} Configuring environment variables..."

if [ -f .env ]; then
    echo -e "${YELLOW}⚠️  .env already exists${NC}"
    read -p "Overwrite with new passwords? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env"
    else
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backup created: .env.backup.*"
        rm .env
    fi
fi

if [ ! -f .env ]; then
    echo "📝 Creating .env with secure passwords..."
    cp .env.example .env
    
    # Generate strong passwords (24 characters each)
    POSTGRES_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    REDIS_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    N8N_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    TOR_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    GRAFANA_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    
    # Replace in .env (cross-platform compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${POSTGRES_PW}/" .env
        sed -i '' "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PW}/" .env
        sed -i '' "s/N8N_PASSWORD=.*/N8N_PASSWORD=${N8N_PW}/" .env
        sed -i '' "s/TOR_CONTROL_PASSWORD=.*/TOR_CONTROL_PASSWORD=${TOR_PW}/" .env
        sed -i '' "s/GRAFANA_PASSWORD=.*/GRAFANA_PASSWORD=${GRAFANA_PW}/" .env
    else
        # Linux
        sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${POSTGRES_PW}/" .env
        sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PW}/" .env
        sed -i "s/N8N_PASSWORD=.*/N8N_PASSWORD=${N8N_PW}/" .env
        sed -i "s/TOR_CONTROL_PASSWORD=.*/TOR_CONTROL_PASSWORD=${TOR_PW}/" .env
        sed -i "s/GRAFANA_PASSWORD=.*/GRAFANA_PASSWORD=${GRAFANA_PW}/" .env
    fi
    
    # Save credentials to file
    cat > .credentials.txt <<EOF
🔑 Generated Credentials ($(date))
═══════════════════════════════════════

n8n:
  URL: http://localhost:5678
  User: admin
  Password: ${N8N_PW}

Grafana:
  URL: http://localhost:3000
  User: admin
  Password: ${GRAFANA_PW}

Prometheus:
  URL: http://localhost:9090
  (No authentication)

⚠️  IMPORTANT: Keep this file secure!
⚠️  Delete after saving credentials to password manager
EOF
    
    chmod 600 .credentials.txt
    
    echo -e "${GREEN}✅ .env created with unique passwords${NC}"
    echo -e "${YELLOW}📋 Credentials saved to .credentials.txt${NC}"
    echo ""
else
    echo -e "${GREEN}✅ Using existing .env${NC}"
    echo ""
fi

# Start services
echo -e "${YELLOW}[3/8]${NC} Starting Docker services..."
echo "This may take 2-3 minutes on first run..."
echo ""

docker-compose up -d --build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start services${NC}"
    echo "Check logs: docker-compose logs"
    exit 1
fi

echo -e "${GREEN}✅ Services started${NC}"
echo ""

# Wait for base services
echo -e "${YELLOW}[4/8]${NC} Waiting for base services to be healthy..."
echo "This takes ~60 seconds (PostgreSQL migrations, Ollama startup)..."
echo ""

SERVICES=("postgres" "redis" "ollama")
for service in "${SERVICES[@]}"; do
    echo -n "  Waiting for ${service}..."
    for i in {1..30}; do
        if docker-compose ps | grep "${service}" | grep -q "(healthy)"; then
            echo -e " ${GREEN}✓${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e " ${RED}✗ (timeout)${NC}"
            echo -e "${YELLOW}⚠️  ${service} not healthy after 60s, but continuing...${NC}"
        fi
        sleep 2
    done
done

echo ""

# Download Ollama model
echo -e "${YELLOW}[5/8]${NC} Checking Ollama model..."

MODEL_EXISTS=$(docker-compose exec -T ollama ollama list 2>/dev/null | grep -c "llama3" || echo "0")

if [ "$MODEL_EXISTS" -eq "0" ]; then
    echo "📥 Downloading Ollama model (llama3.2:3b, ~2 GB)..."
    echo "This is a one-time download and may take 5-10 minutes..."
    echo ""
    
    docker-compose exec -T ollama ollama pull llama3.2:3b
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Model downloaded successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Model download failed, but continuing...${NC}"
        echo "You can manually download later: docker-compose exec ollama ollama pull llama3.2:3b"
    fi
else
    echo -e "${GREEN}✅ Ollama model already present${NC}"
fi
echo ""

# Restart ML service
echo -e "${YELLOW}[6/8]${NC} Restarting ML service with model..."
docker-compose restart ml-service
sleep 5
echo -e "${GREEN}✅ ML service restarted${NC}"
echo ""

# Wait for n8n
echo -e "${YELLOW}[7/8]${NC} Waiting for n8n to be ready..."
echo "n8n is running database migrations (first start only)..."
echo ""

for i in {1..60}; do
    if curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✅ n8n is ready!${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${YELLOW}⚠️  n8n not responding after 120s${NC}"
        echo "Check logs: docker-compose logs n8n"
    fi
    sleep 2
done
echo ""

# Final status check
echo -e "${YELLOW}[8/8]${NC} Checking service status..."
echo ""

docker-compose ps

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo ""
echo "1. Open n8n in browser:"
echo -e "   ${BLUE}http://localhost:5678${NC}"
echo ""
echo "2. Login with credentials from .credentials.txt:"
if [ -f .credentials.txt ]; then
    echo -e "   ${GREEN}User: admin${NC}"
    echo -e "   ${GREEN}Password: (see .credentials.txt)${NC}"
fi
echo ""
echo "3. Import workflows:"
echo "   - Click n8n logo (top-left)"
echo "   - Workflows → Import from File"
echo "   - Select files from workflows/ folder:"
echo "     • workflow-scraper-main.json"
echo "     • workflow-scraper-enhanced.json"
echo "     • control-panel.json"
echo ""
echo "4. Activate each workflow:"
echo "   - Open workflow"
echo "   - Toggle 'Inactive' → 'Active'"
echo ""
echo "5. Test the system:"
echo -e "   ${BLUE}bash tests/master/test_full_e2e.sh${NC}"
echo ""
echo -e "${YELLOW}📊 Service URLs:${NC}"
echo -e "   n8n:        ${BLUE}http://localhost:5678${NC}"
echo -e "   Grafana:    ${BLUE}http://localhost:3000${NC}"
echo -e "   Prometheus: ${BLUE}http://localhost:9090${NC}"
echo ""
echo -e "${YELLOW}🔧 Useful Commands:${NC}"
echo "   View logs:     docker-compose logs -f"
echo "   Restart:       docker-compose restart"
echo "   Stop:          docker-compose down"
echo "   Full cleanup:  docker-compose down -v"
echo ""
echo -e "${RED}⚠️  Security Notice:${NC}"
echo "   • .credentials.txt contains sensitive data"
echo "   • Save passwords to password manager"
echo "   • Delete .credentials.txt after saving"
echo "   • Never commit .env to Git"
echo ""
