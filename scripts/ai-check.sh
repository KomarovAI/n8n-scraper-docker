#!/bin/bash
# AI pre-commit validation for n8n-scraper-docker
# Run this before committing changes to ensure AI-friendly quality

set -e

echo "🤖 Running AI-friendly checks..."

# 1. Validate docker-compose
echo "📋 Validating docker-compose.yml..."
if ! docker-compose config > /dev/null 2>&1; then
    echo "❌ docker-compose.yml validation failed!"
    exit 1
fi
echo "✅ docker-compose.yml is valid"

# 2. Check for hardcoded secrets
echo "🔐 Checking for leaked secrets..."
if grep -r "password.*=.*[^{]" \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=__pycache__ \
    --exclude="*.md" \
    --exclude=".env.example" \
    --exclude="ai-check.sh" \
    --exclude="CONTRIBUTING_AI.md" \
    . 2>/dev/null; then
    echo "❌ Hardcoded password found!"
    echo "Use environment variables instead"
    exit 1
fi
echo "✅ No hardcoded secrets found"

# 3. Check for API keys without @ai-ignore
echo "🔑 Checking API key annotations..."
if grep -r "API_KEY" \
    --exclude-dir=.git \
    --exclude="ai-check.sh" \
    --exclude="*.md" \
    . | grep -v "@ai-ignore" | grep -v "#.*API_KEY" 2>/dev/null; then
    echo "⚠️  API_KEY found without @ai-ignore comment"
    echo "Add '# @ai-ignore' on the same line"
fi

# 4. Validate Python syntax
echo "🐍 Validating Python syntax..."
PYTHON_FILES=$(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" 2>/dev/null)
if [ -n "$PYTHON_FILES" ]; then
    for file in $PYTHON_FILES; do
        if ! python3 -m py_compile "$file" 2>/dev/null; then
            echo "❌ Python syntax error in $file"
            exit 1
        fi
    done
    echo "✅ All Python files are valid"
else
    echo "⚠️  No Python files found"
fi

# 5. Check AI context files exist
echo "📚 Checking AI documentation..."
required_files=(
    ".ai/context.md"
    ".ai/instructions.md"
    "ARCHITECTURE.md"
    "README.md"
    "SECURITY.md"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        exit 1
    fi
done
echo "✅ All AI documentation files present"

# 6. Validate README has AI markers
echo "📖 Validating README.md..."
if ! grep -q "<!-- AI_" README.md 2>/dev/null; then
    echo "⚠️  WARNING: README.md missing AI parsing markers"
    echo "Consider adding <!-- AI_OVERVIEW_START --> markers"
fi

# 7. Check for :latest tags in docker-compose
echo "🐳 Checking Docker image tags..."
if grep -E "image:.*:latest" docker-compose.yml 2>/dev/null; then
    echo "⚠️  WARNING: Found :latest tags in docker-compose.yml"
    echo "Pin versions for production deployments"
fi

# 8. Validate .env.example exists
echo "📦 Checking .env.example..."
if [ ! -f ".env.example" ]; then
    echo "❌ Missing .env.example file"
    exit 1
fi

# Check required variables
required_vars=(
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "N8N_PASSWORD"
)

for var in "${required_vars[@]}"; do
    if ! grep -q "^$var=" .env.example 2>/dev/null; then
        echo "❌ Missing $var in .env.example"
        exit 1
    fi
done
echo "✅ .env.example is valid"

# 9. Check for TODOs in code
echo "📝 Checking for TODOs..."
if grep -r "TODO" \
    --exclude-dir=.git \
    --exclude="ai-check.sh" \
    --exclude="*.md" \
    . 2>/dev/null | grep -v "#.*TODO" | wc -l | grep -q "^0$"; then
    echo "✅ No TODO placeholders found"
else
    echo "⚠️  WARNING: TODO placeholders found in code"
    echo "Complete implementations before committing"
fi

# 10. Final summary
echo ""
echo "====================================="
echo "✅ All AI checks passed!"
echo "====================================="
echo ""
echo "Next steps:"
echo "1. Run tests: bash tests/master/test_full_e2e.sh"
echo "2. Review changes: git diff"
echo "3. Commit: git commit -m 'your message'"
echo ""
