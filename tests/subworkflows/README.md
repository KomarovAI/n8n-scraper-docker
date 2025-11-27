# 🔗 **SUBWORKFLOW TESTING**

## 🎯 **ЧТО ЭТО**

Subworkflow tests = **unit tests для n8n workflows**.

Проверяет:
1. Execute Workflow node **работает**
2. Data **передаётся** между workflows
3. Child workflow **выполняется**
4. Results **возвращаются** в parent
5. Validation logic **функционирует**

---

## 📝 **ФАЙЛЫ**

```
tests/subworkflows/
├── child-workflow.json       # Child workflow (калькулятор)
├── parent-workflow.json      # Parent workflow
├── test-subworkflows.sh      # Test script
└── README.md                 # Эта документация
```

---

## 🐞 **ТЕСТОВЫЕ WORKFLOWS**

### **Child Workflow (Calculator):**

```
Start
  ↓
Calculate (Code Node)
  ↓ Input: {a: 10, b: 5}
  ↓ Output: {sum: 15, product: 50, difference: 5}
```

**Логика:**
```javascript
const a = input.a || 0;
const b = input.b || 0;

return {
  sum: a + b,
  product: a * b,
  difference: a - b
};
```

---

### **Parent Workflow (Orchestrator):**

```
Start
  ↓
Prepare Data (Code Node)
  ↓ Output: {a: 10, b: 5}
  ↓
Execute Child Workflow
  ↓ Calls Calculator child
  ↓ Receives: {sum: 15, product: 50, difference: 5}
  ↓
Validate Result (Code Node)
  ↓ Checks: sum==15, product==50, difference==5
  ↓ Output: {status: 'success', message: '...', childResult: {...}}
```

---

## ⏱️ **ВРЕМЯ ВЫПОЛНЕНИЯ**

```
📥 Import child:         3 сек
📥 Import parent:        3 сек
▶️  Execute parent:       5 сек
⏳ Wait completion:      10 сек
🔍 Validate results:     5 сек
🧹 Cleanup:              2 сек
──────────────────────────
Общее время:        ~28 сек (< 1 мин)
```

---

## 🚀 **КАК ЗАПУСТИТЬ**

```bash
# 1. Запустить n8n
docker-compose up -d postgres redis n8n
sleep 60

# 2. Запустить test
chmod +x tests/subworkflows/test-subworkflows.sh
export N8N_URL="http://localhost:5678"
export N8N_USER="admin"
export N8N_PASSWORD="your_password"

./tests/subworkflows/test-subworkflows.sh

# 3. Cleanup
docker-compose down -v
```

---

## 📈 **ЧТО ЭТО ДАЁТ**

### **Гарантирует, что:**

✅ Execute Workflow node **работает**  
✅ Child workflows **вызываются**  
✅ Data **передаётся** корректно  
✅ Calculations **выполняются** (sum, product, difference)  
✅ Results **возвращаются** в parent  
✅ Parent validation **работает**  

**Критично для модульных workflows!**

---

**Статус:** ✅ **SUBWORKFLOW TESTING READY**  
**Coverage:** Execute Workflow node & data passing  
**Время:** < 1 мин  
