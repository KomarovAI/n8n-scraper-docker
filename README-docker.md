# n8n-scraper-workflow: Docker-setup-ready branch

Ветка подготовлена для бич-энд-плей запуска в Docker Compose — весь стек (n8n, Redis, PostgreSQL, Prometheus, Grafana, ML Service, Ollama, Tor) — сразу работает в режиме production-like на одном сервере или локально.

## Инструкция запуска

1. Клонируйте проект и перейдите в ветку:

```bash
git clone https://github.com/KomarovAI/n8n-scraper-workflow.git
cd n8n-scraper-workflow
git checkout docker
```

2. Скопируйте .env и выставьте пароли (используйте strong-генератор):
```bash
cp .env.example .env
# вручную выставьте все *_PASSWORD
```

3. Запустите полный стек:
```bash
docker-compose up --build
```

4. После старта будут доступны:
- n8n: http://localhost:5678 (user/pass из .env)
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- ML сервис: http://localhost:8000
- Ollama (LLM): http://localhost:11434
- (Redis, PostgreSQL, Tor — локальные, через порты)

5. Для production: откройте нужные порты на firewall, создайте отдельный docker network при необходимости.

## Особенности и best practices
- Все пароли — только в .env (никогда не коммитить)
- Используются официальные образы
- ML/LLM сервис отделён (можно выключать для тестов)
- Мониторинг "из коробки": метрики и дашборды сразу готовы в Grafana
- Сценарии бэкапа — через mount ./backups

## Для Kubernetes используйте ветку main — там StatefulSet и manifests.

---
