#!/bin/bash
set -e

# Unified AI-Optimized Test Reporting - Auto-Apply Script
# This script applies all changes from the implementation guide to ci-test.yml

echo "🚀 Applying Unified AI-Optimized Test Reporting"
echo "================================================="
echo ""

WORKFLOW_FILE=".github/workflows/ci-test.yml"
BACKUP_FILE="${WORKFLOW_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

# Step 1: Backup
echo "📦 Step 1: Creating backup..."
cp "$WORKFLOW_FILE" "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"
echo ""

# Step 2: Add log collection to each job
echo "📋 Step 2: Adding log collection to all jobs..."
echo "⚠️  This requires manual editing of ci-test.yml"
echo ""
echo "Please add these 2 steps to EACH of the 15 jobs:"
echo ""
cat << 'EOF'
      - name: Capture job output logs
        if: always()
        run: |
          mkdir -p /tmp/job-logs
          echo "Job: ${{ github.job }}" > /tmp/job-logs/${{ github.job }}.log
          echo "Status: ${{ job.status }}" >> /tmp/job-logs/${{ github.job }}.log
          echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> /tmp/job-logs/${{ github.job }}.log
          echo "---" >> /tmp/job-logs/${{ github.job }}.log

      - name: Upload job logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: logs-${{ github.job }}-${{ github.run_number }}
          path: /tmp/job-logs/*.log
          retention-days: 7
EOF
echo ""

# Step 3: Instructions for test-summary job
echo "📊 Step 3: Update test-summary job..."
echo ""
echo "Replace the existing test-summary job with enhanced version from:"
echo ".github/docs/UNIFIED_TEST_REPORTING_GUIDE.md"
echo ""
echo "Key changes:"
echo "  1. Enhanced CTRF with message, trace, extra"
echo "  2. Failed tests detailed report"
echo "  3. Metrics report"
echo "  4. Metadata report"
echo "  5. Log download steps"
echo "  6. Unified artifact upload (unified-report/ instead of ctrf/)"
echo ""

# Step 4: Validation
echo "🔍 Step 4: After making changes, validate YAML:"
echo ""
echo "docker run --rm -v \"\${PWD}:/workdir\" mikefarah/yq \\"
echo "  eval '.github/workflows/ci-test.yml' > /dev/null"
echo ""

# Step 5: Commit
echo "💾 Step 5: Commit changes:"
echo ""
echo "git add .github/workflows/ci-test.yml"
echo 'git commit -m "feat(ci): apply unified AI-optimized test reporting"'
echo "git push origin feature/unified-ai-test-reporting"
echo ""

echo "📚 Full instructions: .github/docs/UNIFIED_TEST_REPORTING_GUIDE.md"
echo "⚡ Quick start: .github/docs/QUICK_START_UNIFIED_REPORTING.md"
echo ""
echo "✅ Script completed. Please follow manual steps above."
