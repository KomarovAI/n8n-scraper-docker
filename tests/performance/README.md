# 📊 **LIGHT PERFORMANCE TESTING**

## 🎯 **ЧТО ЭТО**

**Best Practice 2025: Shift-left performance testing!**

Легковесный performance test, который ловит performance regressions **РАНО** (в CI/CD, до production).

---

## 💡 **ПОЧЕМУ ЭТО ВАЖНО**

### **Ловит критичные баги:**

❌ **Memory leaks** — память растёт после каждого выполнения  
❌ **Performance degradation** — изменения замедляют систему  
❌ **Resource exhaustion** — CPU/memory/connections исчерпываются  
❌ **Concurrency issues** — проблемы при параллельной нагрузке  

**Ловит РАНО = экономия дней debugging в production!**

---

## 📝 **ФАЙЛЫ**

```
tests/performance/
├── light-performance-test.sh    # Bash script
└── README.md                    # Эта документация
```

---

## 🔍 **ЧТО ПРОВЕРЯЕТ**

### **Test Scenario:**

```
1. Создать простой test workflow (Code node)
2. Измерить baseline memory
3. Запустить 50 executions (10 параллельно)
4. Измерить final memory
5. Рассчитать метрики
6. Сравнить с thresholds
```

---

### **Метрики:**

#### **1. Error Rate**
```
Error Rate = (Failed / Total) * 100
Threshold: < 5%
```

**Проверяет:**
- ✅ Workflows выполняются без ошибок
- ✅ Нет race conditions
- ✅ Нет concurrency issues

---

#### **2. Execution Time**
```
Avg Execution Time = Total Duration / Success Count
Threshold: < 5000ms (5 seconds)
```

**Проверяет:**
- ✅ Производительность не деградировала
- ✅ Нет неожиданных задержек
- ✅ Нет blocking operations

---

#### **3. Memory Usage**
```
Memory Increase = Final Memory - Baseline Memory
Threshold: < 1024MB
```

**Проверяет:**
- ✅ Нет memory leaks
- ✅ Memory освобождается после executions
- ✅ GC работает корректно

---

## ⏱️ **ВРЕМЯ ВЫПОЛНЕНИЯ**

```
📦 Create workflow:        5s
💾 Measure baseline:       2s
🚀 Execute 50 workflows:   30s (10 concurrent)
⏳ Wait for completion:     30s
📊 Analyze results:        10s
💾 Measure final memory:   2s
🧹 Cleanup:                 5s
──────────────────────────────
Общее время:              84s (~1.5 мин)
```

**Не тяжёлый!** Можно запускать каждый CI/CD run.

**В CI/CD:** Параллельно в волне 2 (~3 мин с overhead)

---

## 🚀 **КАК ЗАПУСТИТЬ**

```bash
# 1. Запустить n8n stack
cp .env.example .env
# Отредактируйте пароли!
docker-compose up -d postgres redis n8n
sleep 60

# 2. Экспортировать переменные
export N8N_USER="admin"
export N8N_PASSWORD="your_password"

# 3. Запустить test
chmod +x tests/performance/light-performance-test.sh
./tests/performance/light-performance-test.sh

# 4. Cleanup
docker-compose down -v
```

---

## 📈 **ПРИМЕР ВЫВОДА**

```
📊 PERFORMANCE METRICS
========================================
Executions:
  Total: 50
  Success: 50
  Errors: 0
  Error rate: 0%

Timing:
  Avg execution time: 234ms
  Threshold: 5000ms

Memory:
  Baseline: 512MB
  Final: 548MB
  Increase: 36MB
  Threshold: 1024MB
========================================

✅ PASS: Error rate within threshold
✅ PASS: Execution time within threshold
✅ PASS: Memory usage within threshold

🎉 LIGHT PERFORMANCE TEST PASSED!
```

---

## ⚠️ **КОГДА FAIL**

### **Scenario 1: High Error Rate**

```
Error rate: 12%
❌ FAIL: Error rate 12% exceeds threshold 5%
```

**Возможные причины:**
- Race conditions
- Database connection pool exhausted
- Concurrency bugs

---

### **Scenario 2: Slow Execution**

```
Avg execution time: 8234ms
❌ FAIL: Avg execution time 8234ms exceeds threshold 5000ms
```

**Возможные причины:**
- Performance regression в коде
- Slow database queries
- Network latency
- Blocking operations

---

### **Scenario 3: Memory Leak**

```
Memory increase: 2048MB
⚠️  WARNING: Memory usage 2560MB exceeds threshold 1024MB
```

**Возможные причины:**
- Memory leak в коде
- Objects не освобождаются
- Event listeners не удаляются
- Connection leaks

---

## 📈 **ЧТО ЭТО ДАЁТ**

### **Гарантирует:**

✅ **Performance regressions ловятся РАНО**  
✅ **Memory leaks обнаруживаются**  
✅ **Concurrency issues проявляются**  
✅ **Resource exhaustion предотвращается**  

**Shift-left testing = экономия времени и денег!**

---

## 📚 **BEST PRACTICES**

### **1. Run on Every CI/CD**

Легковесный тест (<3 мин) → можно запускать каждый push.

---

### **2. Adjust Thresholds**

```bash
# Для более сложных workflows:
MAX_AVG_EXECUTION_TIME=10000  # 10s

# Для более строгой проверки:
MAX_ERROR_RATE=1  # 1%
```

---

### **3. Monitor Trends**

Сохраняйте метрики в CI artifacts для анализа трендов:

```
Build #123: 234ms, 36MB increase
Build #124: 251ms, 38MB increase
Build #125: 8234ms, 2048MB increase  ⚠️  REGRESSION!
```

---

**Статус:** ✅ **SHIFT-LEFT TESTING**  
**Время:** ~3 мин  
**Ценность:** ⭐⭐⭐⭐⭐ (ловит performance bugs РАНО!)  
