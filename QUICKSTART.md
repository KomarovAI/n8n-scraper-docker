# Quickstart 🚀

## 5 commands to launch

```bash
# 1. Clone
git clone https://github.com/KomarovAI/n8n-scraper-docker.git && cd n8n-scraper-docker

# 2. Generate passwords (run 5 times for each service)
openssl rand -base64 24

# 3. Setup env
cp .env.example .env && nano .env  # Replace all CHANGE_ME_* with generated passwords

# 4. Launch
docker-compose up -d --build

# 5. Check
docker-compose ps && docker-compose logs -f
```

## Access URLs

- n8n: http://localhost:5678
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

## Critical env variables

All must be 20+ characters:
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `N8N_PASSWORD`
- `TOR_CONTROL_PASSWORD`
- `GRAFANA_PASSWORD`

## Quick commands

```bash
# Stop
docker-compose down

# Restart
docker-compose restart

# Logs
docker-compose logs -f [service-name]

# Update
git pull && docker-compose up -d --build
```

## Next steps

1. Open n8n (localhost:5678)
2. Import workflows from `workflows/`
3. Check Grafana dashboards (localhost:3000)
4. Run test workflow

See `README.md` for full docs.
