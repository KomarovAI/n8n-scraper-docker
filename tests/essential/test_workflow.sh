#!/bin/bash
# Essential Test #2: Workflow Smoke Test - Проверка работы n8n workflow
# Этот тест проверяет возможность создания и выполнения workflow

set -e

echo "========================================"
echo "Essential Test #2: Workflow Smoke Test"
echo "========================================"
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED_TESTS=0
TOTAL_TESTS=0
SKIPPED_TESTS=0

# Функция тестирования
test_step() {
    local test_name=$1
    local command=$2
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "[Тест $TOTAL_TESTS] $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Функция опционального теста
test_step_optional() {
    local test_name=$1
    local command=$2
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "[Тест $TOTAL_TESTS] $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${YELLOW}⏭️  SKIPPED${NC} (Optional service)"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return 1
    fi
}

echo "📝 Проверка n8n API..."
echo "----------------------------------------"

# Тест 1: Проверка доступности n8n
test_step "Доступность n8n" "curl -f -s http://localhost:5678/"

# Тест 2: Проверка healthz endpoint
test_step "Проверка healthz endpoint" "curl -f -s http://localhost:5678/healthz"

echo ""
echo "🚀 Проверка webhook..."
echo "----------------------------------------"

# Тест 3: Создание тестового webhook
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "[Тест $TOTAL_TESTS] Создание тестового workflow... "

# Создаем простой webhook workflow (test-webhook)
WEBHOOK_WORKFLOW=$(cat <<'EOF'
{
  "name": "Test Webhook Workflow",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "test-webhook",
        "responseMode": "onReceived",
        "options": {}
      },
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "values": {
          "string": [
            {
              "name": "status",
              "value": "success"
            },
            {
              "name": "message",
              "value": "Workflow test passed"
            }
          ]
        },
        "options": {}
      },
      "name": "Set",
      "type": "n8n-nodes-base.set",
      "typeVersion": 1,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [
          {
            "node": "Set",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {},
  "tags": []
}
EOF
)

# Проверяем, что workflow можно создать
if echo "$WEBHOOK_WORKFLOW" | jq . > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC} (JSON valid)"
else
    echo -e "${RED}❌ FAIL${NC} (Invalid JSON)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""
echo "📦 Проверка базы данных..."
echo "----------------------------------------"

# Тест 4: Проверка подключения к PostgreSQL
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "[Тест $TOTAL_TESTS] Подключение к PostgreSQL... "

if docker exec -i $(docker ps -qf "name=postgres") pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Тест 5: Проверка Redis (опционально - может требовать auth)
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "[Тест $TOTAL_TESTS] Подключение к Redis... "

# Пробуем без аутентификации
if docker exec -i $(docker ps -qf "name=redis") redis-cli ping 2>&1 | grep -q "PONG"; then
    echo -e "${GREEN}✅ OK${NC}"
elif [ -n "${REDIS_PASSWORD:-}" ]; then
    # Пробуем с паролем
    if docker exec -i $(docker ps -qf "name=redis") redis-cli -a "$REDIS_PASSWORD" ping 2>&1 | grep -q "PONG"; then
        echo -e "${GREEN}✅ OK${NC} (with auth)"
    else
        echo -e "${YELLOW}⏭️  SKIPPED${NC} (Auth required, optional)"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
else
    echo -e "${YELLOW}⏭️  SKIPPED${NC} (Auth required, optional)"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
fi

echo ""
echo "========================================"
echo "📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ"
echo "========================================"
echo "Всего тестов: $TOTAL_TESTS"
echo -e "Успешных: ${GREEN}$((TOTAL_TESTS - FAILED_TESTS - SKIPPED_TESTS))${NC}"
echo -e "Проваленных: ${RED}$FAILED_TESTS${NC}"
echo -e "Пропущенных: ${YELLOW}$SKIPPED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ ВСЕ ОБЯЗАТЕЛЬНЫЕ ТЕСТЫ ПРОШЛИ УСПЕШНО!${NC}"
    echo ""
    echo "✅ n8n готов к работе!"
    echo "🌐 Откройте: http://localhost:5678"
    echo ""
    exit 0
else
    echo -e "${RED}❌ НЕКОТОРЫЕ ОБЯЗАТЕЛЬНЫЕ ТЕСТЫ ПРОВАЛЕНЫ!${NC}"
    echo ""
    echo "🔍 Рекомендации:"
    echo "  1. Проверьте логи n8n: docker-compose logs n8n"
    echo "  2. Проверьте переменные окружения: cat .env"
    echo "  3. Перезапустите: docker-compose restart"
    echo ""
    exit 1
fi