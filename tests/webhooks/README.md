# 🔗 **WEBHOOK TESTING**

## 🎯 **ЧТО ЭТО**

Webhook tests проверяют **entry points** ваших n8n automations.

Проверяет:
1. Webhook endpoints **доступны**
2. Workflow **активируется** корректно
3. Payload **принимается** и обрабатывается
4. Response **возвращается** корректно
5. Respond to Webhook node **работает**

---

## 📝 **ФАЙЛЫ**

```
tests/webhooks/
├── test-webhook.json      # Workflow с webhook node
├── sample-payload.json    # Пример payload
├── test-webhooks.sh       # Test script
└── README.md              # Эта документация
```

---

## 🐞 **ТЕСТОВЫЙ WEBHOOK WORKFLOW**

### **Структура:**

```
Webhook (POST /webhook/test-hook)
  ↓
Process Webhook (validate & transform)
  ↓
Respond to Webhook (return JSON)
```

### **Webhook Node:**
```json
{
  "httpMethod": "POST",
  "path": "test-hook",
  "responseMode": "responseNode"
}
```

### **Process Node:**
```javascript
const payload = $input.first().json;

return {
  json: {
    status: 'success',
    message: 'Webhook received',
    receivedData: payload,
    timestamp: new Date().toISOString()
  }
};
```

---

## ⏱️ **ВРЕМЯ ВЫПОЛНЕНИЯ**

```
📥 Import workflow:      3 сек
▶️  Activate workflow:    2 сек
⏳ Wait registration:    5 сек
📨 Send payload:         2 сек
✅ Validate response:    2 сек
🧹 Cleanup:              2 сек
──────────────────────────
Общее время:         ~16 сек (< 1 мин)
```

---

## 🚀 **КАК ЗАПУСТИТЬ**

```bash
# 1. Запустить n8n
docker-compose up -d postgres redis n8n
sleep 60

# 2. Запустить test
chmod +x tests/webhooks/test-webhooks.sh
export N8N_URL="http://localhost:5678"
export N8N_USER="admin"
export N8N_PASSWORD="your_password"

./tests/webhooks/test-webhooks.sh

# 3. Cleanup
docker-compose down -v
```

---

## 📈 **ЧТО ЭТО ДАЁТ**

### **Гарантирует, что:**

✅ Webhook endpoints **регистрируются**  
✅ Workflow activation **работает**  
✅ POST requests **принимаются**  
✅ Payload **парсится** корректно  
✅ Respond to Webhook **функционирует**  
✅ JSON response **возвращается**  

**Критично для production triggers!**

---

**Статус:** ✅ **WEBHOOK TESTING READY**  
**Coverage:** Webhook endpoints & activation  
**Время:** < 1 мин  
