#!/bin/bash
# Essential Test #1: Health Check - Проверка доступности всех сервисов
# Этот тест проверяет основную работоспособность всех критичных сервисов

set -e

echo "========================================"
echo "Essential Test #1: Health Check"
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

# Функция проверки сервиса (обязательный)
check_service() {
    local service_name=$1
    local url=$2
    local expected_code=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "[Тест $TOTAL_TESTS] Проверка $service_name... "
    
    # Проверяем HTTP ответ
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
    
    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP $http_code)"
    else
        echo -e "${RED}❌ FAIL${NC} (Expected HTTP $expected_code, got HTTP $http_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Функция проверки опционального сервиса
check_service_optional() {
    local service_name=$1
    local url=$2
    local expected_code=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "[Тест $TOTAL_TESTS] Проверка $service_name... "
    
    # Проверяем HTTP ответ
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    
    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP $http_code)"
    elif [ "$http_code" = "000" ]; then
        echo -e "${YELLOW}⏭️  SKIPPED${NC} (Service not running)"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} (Expected HTTP $expected_code, got HTTP $http_code)"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
}

# Функция проверки Docker контейнера
check_container() {
    local container_name=$1
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "[Тест $TOTAL_TESTS] Проверка контейнера $container_name... "
    
    # Проверяем статус контейнера
    status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" | head -1)
    
    if [ -n "$status" ] && echo "$status" | grep -q "Up"; then
        echo -e "${GREEN}✅ OK${NC} ($status)"
    else
        echo -e "${RED}❌ FAIL${NC} (Container not running or not found)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo "📊 Проверка Docker контейнеров..."
echo "----------------------------------------"

# Проверяем критичные контейнеры
check_container "n8n"
check_container "postgres"
check_container "redis"

echo ""
echo "🌐 Проверка HTTP эндпоинтов..."
echo "----------------------------------------"

# Проверяем обязательные сервисы
check_service "n8n" "http://localhost:5678/" "200"

# Проверяем опциональные сервисы (не падаем если их нет)
check_service_optional "Prometheus" "http://localhost:9090/-/healthy" "200"
check_service_optional "Grafana" "http://localhost:3000/api/health" "200"

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
    exit 0
else
    echo -e "${RED}❌ НЕКОТОРЫЕ ОБЯЗАТЕЛЬНЫЕ ТЕСТЫ ПРОВАЛЕНЫ!${NC}"
    echo ""
    echo "🔍 Рекомендации:"
    echo "  1. Проверьте статус контейнеров: docker-compose ps"
    echo "  2. Просмотрите логи: docker-compose logs"
    echo "  3. Перезапустите сервисы: docker-compose restart"
    echo ""
    exit 1
fi