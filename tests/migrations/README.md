# 📦 **DATABASE MIGRATION TESTING**

## 🎯 **ЧТО ЭТО**

Критичный тест для production deployments!

Проверяет:
1. **Migrations apply** без ошибок
2. **Schema creates** корректно
3. **Data operations** работают
4. **Indexes functional**
5. **Constraints enforced**
6. **Idempotency** (можно применять повторно)
7. **Data integrity** сохраняется

---

## 💡 **ПОЧЕМУ ЭТО ВАЖНО**

### **Ловит критичные баги:**

❌ **Breaking migrations** — миграция ломает схему  
❌ **Data loss** — миграция удаляет данные  
❌ **Constraint violations** — новые ограничения конфликтуют  
❌ **Index missing** — индексы не создались  
❌ **Non-idempotent** — повторное применение ломает БД  

**Эти баги в production = DOWNTIME!**

---

## 📝 **ФАЙЛЫ**

```
tests/migrations/
├── test-migrations.sh    # Bash script для migration testing
├── README.md             # Эта документация
└── ../migrations/        # Директория с SQL миграциями
    └── 001_init.sql      # Пример миграции
```

---

## 🔍 **ЧТО ПРОВЕРЯЕТ**

### **Test 1: Migration Application**

```sql
-- Применяет все .sql файлы из migrations/
FOR EACH migration IN migrations/*.sql:
  psql < migration
```

**Проверяет:**
- ✅ SQL syntax корректен
- ✅ Нет конфликтующих изменений
- ✅ Dependencies разрешены

---

### **Test 2: Schema Verification**

```sql
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema='public';

SELECT MAX(version) FROM schema_version;
```

**Проверяет:**
- ✅ Таблицы созданы
- ✅ schema_version существует
- ✅ Версия схемы корректна

---

### **Test 3: Data Operations**

```sql
INSERT INTO workflows (name, data, active) 
VALUES ('test', '{}'::jsonb, true);

SELECT COUNT(*) FROM workflows WHERE name='test';
```

**Проверяет:**
- ✅ INSERT работает
- ✅ SELECT работает
- ✅ Data types корректны (JSONB, BOOLEAN)

---

### **Test 4: Index Performance**

```sql
EXPLAIN SELECT * FROM workflows WHERE active = true;
```

**Проверяет:**
- ✅ Index Scan используется
- ✅ Индексы созданы

---

### **Test 5: Constraint Enforcement**

```sql
-- Попытка вставить duplicate primary key
INSERT INTO schema_version (version) VALUES (1);
-- Должно fail с "duplicate key"
```

**Проверяет:**
- ✅ Primary key constraints работают
- ✅ Unique constraints работают

---

### **Test 6: Idempotency**

```bash
# Применить migrations повторно
for migration in migrations/*.sql; do
  psql < migration
done

# Проверить что данные сохранились
```

**Проверяет:**
- ✅ Повторное применение не ломает
- ✅ Данные сохранены
- ✅ IF NOT EXISTS работает

---

## ⏱️ **ВРЕМЯ ВЫПОЛНЕНИЯ**

```
📦 Apply migrations:        30s
🔍 Verify schema:           15s
💾 Test data ops:           20s
🔒 Test constraints:        15s
🔁 Test idempotency:        30s
──────────────────────────────
Общее время:                110s (~2 мин)
```

**В CI/CD:** Параллельно в волне 2

---

## 🚀 **КАК ЗАПУСТИТЬ**

```bash
# 1. Запустить PostgreSQL
cp .env.example .env
docker-compose up -d postgres
sleep 30

# 2. Запустить test
chmod +x tests/migrations/test-migrations.sh
./tests/migrations/test-migrations.sh

# 3. Cleanup
docker-compose down -v
```

---

## 📈 **ЧТО ЭТО ДАЁТ**

### **Гарантирует:**

✅ Migrations **применяются** без ошибок  
✅ Schema **создаётся** корректно  
✅ Data operations **работают**  
✅ Indexes **функционируют**  
✅ Constraints **соблюдаются**  
✅ Idempotency **гарантирована**  
✅ Data integrity **сохраняется**  

**Критично для production deployments!**

---

## 📚 **BEST PRACTICES**

### **1. Нумерация миграций:**

```
migrations/
├── 001_init.sql
├── 002_add_users.sql
├── 003_add_indexes.sql
└── 004_add_constraints.sql
```

### **2. Idempotent SQL:**

```sql
-- ✅ ХОРОШО
CREATE TABLE IF NOT EXISTS workflows (...);
CREATE INDEX IF NOT EXISTS idx_name ON table(column);

-- ❌ ПЛОХО
CREATE TABLE workflows (...);
CREATE INDEX idx_name ON table(column);
```

### **3. Schema Version Tracking:**

```sql
CREATE TABLE schema_version (
  version INT PRIMARY KEY,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO schema_version (version) VALUES (1);
```

---

**Статус:** ✅ **CRITICAL FOR PRODUCTION**  
**Время:** ~2 мин  
**Ценность:** ⭐⭐⭐⭐⭐ (ловит production-breaking bugs)  
