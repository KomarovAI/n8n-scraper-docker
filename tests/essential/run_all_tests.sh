#!/bin/bash
# Essential Tests Runner - Запуск всех базовых тестов

set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "============================================"
echo "  🧪 ESSENTIAL SMOKE TESTS"
echo "  n8n-scraper-docker"
echo "============================================"
echo ""
echo "📅 $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

FAILED_TESTS=0
TOTAL_TESTS=2

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    exit 1
fi

# Проверяем наличие docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose не установлен!${NC}"
    exit 1
fi

echo -e "${CYAN}🛠️  Инструменты:${NC}"
echo "  - Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  - Docker Compose: $(docker-compose --version | cut -d' ' -f4 | tr -d ',')"
echo ""

echo -e "${CYAN}📂 Запуск тестов:${NC}"
echo ""

# Тест #1: Health Check
echo -e "${YELLOW}➡️  ТЕСТ 1/2: Health Check${NC}"
if bash "$CURRENT_DIR/test_health.sh"; then
    echo -e "${GREEN}✅ Test 1 прошел успешно${NC}"
else
    echo -e "${RED}❌ Test 1 провален${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""
echo "-------------------------------------------"
echo ""

# Тест #2: Workflow Smoke Test
echo -e "${YELLOW}➡️  ТЕСТ 2/2: Workflow Smoke Test${NC}"
if bash "$CURRENT_DIR/test_workflow.sh"; then
    echo -e "${GREEN}✅ Test 2 прошел успешно${NC}"
else
    echo -e "${RED}❌ Test 2 провален${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""
echo "============================================"
echo "🏁 ИТОГОВЫЕ РЕЗУЛЬТАТЫ"
echo "============================================"
echo "Всего тестов: $TOTAL_TESTS"
echo -e "Успешных: ${GREEN}$((TOTAL_TESTS - FAILED_TESTS))${NC}"
echo -e "Проваленных: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✅ ВСЕ ТЕСТЫ ПРОШЛИ УСПЕШНО!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "✅ Система готова к работе!"
    echo "🌐 n8n: http://localhost:5678"
    echo "📊 Grafana: http://localhost:3000"
    echo "🔥 Prometheus: http://localhost:9090"
    echo ""
    exit 0
else
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}❌ НЕКОТОРЫЕ ТЕСТЫ ПРОВАЛЕНЫ!${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo "🔍 Действия по устранению:"
    echo "  1. Проверьте статус: docker-compose ps"
    echo "  2. Просмотрите логи: docker-compose logs"
    echo "  3. Перезапустите: docker-compose restart"
    echo "  4. Полный перезапуск: docker-compose down && docker-compose up -d"
    echo ""
    exit 1
fi
