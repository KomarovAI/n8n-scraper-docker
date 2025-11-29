# GitHub Actions Workflow Best Practices

## 📋 Оглавление

- [Основы YAML синтаксиса](#основы-yaml-синтаксиса)
- [Специфика GitHub Actions](#специфика-github-actions)
- [Работа с секретами](#работа-с-секретами)
- [Типичные ошибки](#типичные-ошибки)
- [Отладка](#отладка)
- [Безопасность](#безопасность)

---

## Основы YAML синтаксиса

### ✅ Что МОЖНО делать в YAML

```yaml
# 1. Комментарии с # в начале строки
# Это безопасный комментарий

# 2. Многострочные строки с | или >
script: |
  echo "Line 1"
  echo "Line 2"

# 3. Переменные окружения
env:
  MY_VAR: "value"

# 4. Массивы
list:
  - item1
  - item2
  
# Inline формат
list: [item1, item2]

# 5. Словари
dict:
  key1: value1
  key2: value2
  
# Inline формат
dict: {key1: value1, key2: value2}

# 6. Якоря и ссылки (для переиспользования)
defaults: &defaults
  timeout: 10
  retries: 3

job1:
  <<: *defaults
  name: "Job 1"
```

### ❌ Что НЕЛЬЗЯ делать в YAML

```yaml
# 1. ЗАПРЕЩЕНО: Табы для отступов (только пробелы!)
❌ 	job_name:  # TAB = ошибка!
✅  job_name:  # 2 пробела = OK

# 2. ЗАПРЕЩЕНО: Смешанные отступы
❌ job:
   step1:  # 3 пробела
    step2:  # 4 пробела = несовместимо!

✅ job:
  step1:  # 2 пробела
  step2:  # 2 пробела = OK

# 3. ЗАПРЕЩЕНО: Спецсимволы без кавычек
❌ name: Цена: $100  # Двоеточие после букв без кавычек
✅ name: "Цена: $100"  # Кавычки решают проблему

# 4. ЗАПРЕЩЕНО: Пустые ключи
❌ :
  value: 123
  
✅ key:
  value: 123
```

---

## Специфика GitHub Actions

### 🎯 Контексты GitHub Actions

```yaml
# Доступные контексты:
${{ github.sha }}           # Хэш коммита
${{ github.ref }}           # Ссылка (refs/heads/main)
${{ github.actor }}         # Пользователь
${{ job.status }}           # Статус задания
${{ steps.step_id.outputs.var }}  # Выходные данные шага
${{ secrets.SECRET_NAME }}  # Секреты (см. раздел ниже)
${{ matrix.value }}         # Значение из матрицы
```

### ⚙️ Переменные окружения

```yaml
# Глобальный уровень (для всех job)
env:
  GLOBAL_VAR: "value"

jobs:
  test:
    # Уровень job (для всех steps в job)
    env:
      JOB_VAR: "value"
    
    steps:
      # Уровень step (только для этого step)
      - name: Step
        env:
          STEP_VAR: "value"
        run: echo $STEP_VAR
```

### 📦 Outputs между jobs

```yaml
jobs:
  job1:
    outputs:
      result: ${{ steps.compute.outputs.value }}
    steps:
      - id: compute
        run: echo "value=123" >> $GITHUB_OUTPUT
  
  job2:
    needs: job1
    steps:
      - run: echo "Result: ${{ needs.job1.outputs.result }}"
```

---

## Работа с секретами

### ⚠️ КРИТИЧЕСКИ ВАЖНО: Безопасная обработка секретов

#### ❌ НЕПРАВИЛЬНО: Прямая подстановка в here-doc

```yaml
# ПРОБЛЕМА: GitHub Actions подставляет секреты ДО shell-обработки!
# Если секрет содержит $ ` \ " - YAML ломается!

steps:
  - run: |
      cat > .env << EOF
      PASSWORD=${{ secrets.PASSWORD }}  # ❌ ОПАСНО!
      EOF

# Если PASSWORD = "Pa$$w0rd!" → YAML syntax error!
# Если PASSWORD = "test`rm -rf`" → command injection!
```

#### ✅ ПРАВИЛЬНО: Job-level env + bash-переменные

```yaml
jobs:
  deploy:
    env:
      # Секреты на уровне job - безопасны!
      PASSWORD_CI: ${{ secrets.PASSWORD }}
      API_KEY_CI: ${{ secrets.API_KEY }}
      TOKEN_CI: ${{ secrets.TOKEN }}
    
    steps:
      - run: |
          cat > .env << EOF
          PASSWORD=${PASSWORD_CI}
          API_KEY=${API_KEY_CI}
          TOKEN=${TOKEN_CI}
          EOF

# Bash автоматически экранирует спецсимволы!
# Работает с ЛЮБЫМИ значениями секретов!
```

### 🔒 Защита секретов в логах

```yaml
# GitHub автоматически маскирует секреты в логах
steps:
  - run: |
      echo "Password: ${{ secrets.PASSWORD }}"  # → "Password: ***"
      
# НО! Избегайте:
  - run: |
      # ❌ Base64 не защищает!
      echo "${{ secrets.PASSWORD }}" | base64  # Видно в логах!
      
      # ❌ Переприсваивание в другую переменную
      MY_VAR="${{ secrets.PASSWORD }}"
      echo "$MY_VAR"  # НЕ маскируется!
```

### 🎯 Передача секретов в скрипты

```yaml
env:
  API_KEY_CI: ${{ secrets.API_KEY }}
  SECRET_TOKEN_CI: ${{ secrets.SECRET_TOKEN }}

steps:
  # ✅ Через export в shell
  - run: |
      export API_KEY="${API_KEY_CI}"
      export SECRET_TOKEN="${SECRET_TOKEN_CI}"
      ./my-script.sh
  
  # ✅ Через env прямо в действие
  - uses: some/action@v1
    env:
      API_KEY: ${{ secrets.API_KEY }}
  
  # ❌ НЕ передавайте как аргументы командной строки!
  - run: ./script.sh ${{ secrets.API_KEY }}  # Видно в ps aux!
```

---

## Типичные ошибки

### ❌ Ошибка 1: "error in your yaml syntax on line X"

**Причины:**
1. Табы вместо пробелов
2. Неправильные отступы
3. Спецсимволы без кавычек
4. Секреты с спецсимволами в here-doc

**Решение:**
```yaml
# ВСЕГДА используйте:
- 2 пробела для отступов (не табы!)
- Кавычки для строк со спецсимволами: ":[]{}@#"
- Job-level env для секретов
```

### ❌ Ошибка 2: "Invalid workflow file"

**Проверьте:**
```bash
# Локальная валидация (установите actionlint)
brew install actionlint  # macOS
apt install actionlint   # Ubuntu

actionlint .github/workflows/*.yaml
```

### ❌ Ошибка 3: Секреты не работают

**Чеклист:**
- [ ] Секрет существует в Settings → Secrets → Actions?
- [ ] Имя секрета EXACT_MATCH (регистрозависимо)?
- [ ] Используете `${{ secrets.NAME }}`, не `${{ env.NAME }}`?
- [ ] Job-level env для safe подстановки?

### ❌ Ошибка 4: Matrix не генерируется

```yaml
# ❌ НЕПРАВИЛЬНО
matrix:
  version: [12, 14, 16]  # Числа без кавычек!

# ✅ ПРАВИЛЬНО
matrix:
  version: ["12", "14", "16"]  # Строки в кавычках
  # ИЛИ
  version:
    - "12"
    - "14"
    - "16"
```

---

## Отладка

### 🔍 Инструменты диагностики

```yaml
steps:
  # 1. Проверка переменных окружения
  - name: Debug ENV
    run: |
      echo "=== Environment ==="
      env | sort
      echo "=== GitHub Context ==="
      echo "SHA: ${{ github.sha }}"
      echo "Ref: ${{ github.ref }}"
      echo "Actor: ${{ github.actor }}"
  
  # 2. Проверка файловой системы
  - name: Debug FS
    run: |
      echo "=== Working Directory ==="
      pwd
      ls -la
      echo "=== /tmp ==="
      ls -la /tmp
  
  # 3. Проверка Docker
  - name: Debug Docker
    run: |
      echo "=== Docker Info ==="
      docker --version
      docker compose version
      docker ps -a
      echo "=== Images ==="
      docker images
  
  # 4. Проверка сети
  - name: Debug Network
    run: |
      echo "=== Network ==="
      netstat -tuln | grep LISTEN
      curl -v http://localhost:5678 || true
```

### 🐛 Режим отладки

```yaml
# Включите в Settings → Secrets:
# ACTIONS_STEP_DEBUG = true
# ACTIONS_RUNNER_DEBUG = true

# В workflow появятся детальные логи:
# [DEBUG] Step starting...
# [DEBUG] Command: ...
```

### 📊 Логи и артефакты

```yaml
steps:
  - name: Test
    run: |
      ./run-tests.sh 2>&1 | tee /tmp/test.log
    continue-on-error: true
  
  - name: Upload logs
    if: always()
    uses: actions/upload-artifact@v5
    with:
      name: test-logs
      path: /tmp/test.log
      retention-days: 7
```

---

## Безопасность

### 🔐 Best Practices

```yaml
# 1. Минимальные permissions
permissions:
  contents: read  # Только чтение
  packages: write  # Запись только если нужно

# 2. Pinned versions (SHA вместо тега)
steps:
  - uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608  # v4.1.0
    # Не просто: actions/checkout@v4

# 3. Изоляция секретов
env:
  # ✅ Job-level для CI секретов
  DB_PASSWORD_CI: ${{ secrets.DB_PASSWORD_CI }}
  # ❌ НЕ используйте продакшн-секреты в CI!

# 4. continue-on-error осторожно
steps:
  - name: Security scan
    run: ./security-scan.sh
    continue-on-error: false  # FAIL если небезопасно!
  
  - name: Optional lint
    run: ./lint.sh
    continue-on-error: true  # OK если упадет

# 5. Secrets не в URL/args
steps:
  - run: |
      # ❌ ОПАСНО
      curl https://api.example.com?token=${{ secrets.TOKEN }}
      
      # ✅ БЕЗОПАСНО
      curl -H "Authorization: Bearer $TOKEN" https://api.example.com
    env:
      TOKEN: ${{ secrets.TOKEN }}
```

### 🛡️ Защита от injection

```yaml
steps:
  # ❌ ОПАСНО: User input без валидации
  - run: |
      echo "Branch: ${{ github.head_ref }}"  # Может содержать `rm -rf /`!
  
  # ✅ БЕЗОПАСНО: Input через env
  - run: |
      echo "Branch: ${BRANCH_NAME}"
    env:
      BRANCH_NAME: ${{ github.head_ref }}
  
  # ✅ ЕЩЕ БЕЗОПАСНЕЕ: Валидация
  - run: |
      if [[ "${BRANCH_NAME}" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
        echo "Branch: ${BRANCH_NAME}"
      else
        echo "Invalid branch name"
        exit 1
      fi
    env:
      BRANCH_NAME: ${{ github.head_ref }}
```

---

## Полезные ссылки

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [YAML Spec](https://yaml.org/spec/1.2/spec.html)
- [Actions Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Contexts](https://docs.github.com/en/actions/learn-github-actions/contexts)

---

## 🎯 Чеклист перед коммитом

- [ ] Используются только пробелы (не табы)
- [ ] Отступы консистентны (2 пробела)
- [ ] Секреты через job-level `env:`
- [ ] Спецсимволы в кавычках
- [ ] Pinned action versions (SHA)
- [ ] `continue-on-error` обоснован
- [ ] Логи/артефакты для отладки
- [ ] Нет секретов в URL/args
- [ ] Проверено `actionlint`
- [ ] Tested locally with `act` (опционально)

---

**Версия:** 1.0  
**Дата:** 2025-11-29  
**Основано на:** Отладка `ci-max-parallel-clean.yaml` (commits `0cfa4f6` → `8bb3ef2`)
