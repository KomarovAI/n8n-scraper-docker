# CTRF AI-Optimized Test Reporting

Этот директорий содержит конфигурацию и отчёты для **CTRF (Common Test Report Format)** - современного стандарта 2025 для test reporting с минимальным footprint и оптимизацией для AI/LLM.

## 🎯 Что такое CTRF?

**CTRF (Common Test Report Format)** - это универсальный JSON-формат для отчётов о тестировании, который:

✅ **Минимальный** - только самая нужная информация (≈100-300 токенов)  
✅ **Универсальный** - работает с любыми тестами (bash, Node.js, Python, Java)  
✅ **AI-ready** - оптимизирован для LLM/AI-анализа  
✅ **GitHub-native** - интегрирован в GitHub Actions Summary  

## 📊 Что в отчёте?

Наш CTRF-отчёт содержит:

```json
{
  "results": {
    "tool": {
      "name": "n8n-scraper-docker",
      "version": "3.0"
    },
    "summary": {
      "tests": 12,
      "passed": 12,
      "failed": 0,
      "pending": 0,
      "skipped": 0,
      "start": 1732734000000,
      "stop": 1732734600000
    },
    "tests": [
      {
        "name": "Fast Validation",
        "status": "passed",
        "duration": 300000
      },
      {
        "name": "Smoke Tests (Parallel x5)",
        "status": "passed",
        "duration": 600000
      },
      // ... и т.д.
    ]
  }
}
```

## 🚀 Как это работает?

1. **Генерация**: GitHub Actions workflow автоматически генерирует CTRF-отчёт после всех тестов
2. **Агрегация**: Все 12 jobs объединяются в один отчёт
3. **Публикация**: `ctrf-io/github-test-reporter` отображает результаты в Actions Summary

## 💾 Где находятся отчёты?

- **GitHub Actions Summary**: Прямо в интерфейсе GitHub
- **Artifacts**: `ctrf-report.json` сохраняется как artifact на 30 дней
- **Local**: Можно скачать из artifacts любого workflow run

## 🔗 Полезные ссылки

- [CTRF GitHub Test Reporter](https://github.com/ctrf-io/github-test-reporter)
- [CTRF Format Specification](https://ctrf.io/)
- [CTRF Ecosystem](https://github.com/ctrf-io)

---

*🤖 AI-Optimized | 📊 Minimal Context | 🚀 Production-Ready*
