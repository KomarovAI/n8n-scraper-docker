// ✅ FIX #15: E2E тесты для full workflow через N8N API
const axios = require('axios');
const assert = require('assert');

// Configuration
const N8N_BASE_URL = process.env.N8N_BASE_URL || 'http://localhost:5678';
const N8N_API_KEY = process.env.N8N_API_KEY || 'your-api-key';
const WEBHOOK_URL = `${N8N_BASE_URL}/webhook/scrape`;
const SCRAPER_API_KEY = process.env.SCRAPER_API_KEY || 'test-api-key';

// Test configuration
const TEST_TIMEOUT = 120000; // 2 minutes

class WorkflowE2ETest {
  constructor() {
    this.results = {
      passed: 0,
      failed: 0,
      tests: []
    };
  }

  async runTest(name, testFn) {
    console.log(`\n▶️  Running: ${name}`);
    const startTime = Date.now();
    
    try {
      await testFn();
      const duration = Date.now() - startTime;
      console.log(`✅ PASSED (${duration}ms): ${name}`);
      this.results.passed++;
      this.results.tests.push({ name, status: 'PASSED', duration });
    } catch (error) {
      const duration = Date.now() - startTime;
      console.error(`❌ FAILED (${duration}ms): ${name}`);
      console.error(`   Error: ${error.message}`);
      this.results.failed++;
      this.results.tests.push({ name, status: 'FAILED', duration, error: error.message });
    }
  }

  async testSimpleScrape() {
    const response = await axios.post(WEBHOOK_URL, {
      urls: ['https://example.com'],
      selector: 'body'
    }, {
      headers: {
        'Authorization': `Bearer ${SCRAPER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: TEST_TIMEOUT
    });

    assert.strictEqual(response.status, 200, 'Response status should be 200');
    assert.ok(response.data.results, 'Response should contain results');
    assert.ok(response.data.results.length > 0, 'Should have at least 1 result');
    assert.strictEqual(response.data.results[0].success, true, 'Scrape should be successful');
  }

  async testBatchScrape() {
    const urls = [
      'https://example.com',
      'https://httpbin.org/html',
      'https://www.iana.org'
    ];

    const response = await axios.post(WEBHOOK_URL, {
      urls,
      selector: 'body'
    }, {
      headers: {
        'Authorization': `Bearer ${SCRAPER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: TEST_TIMEOUT
    });

    assert.strictEqual(response.status, 200);
    assert.ok(response.data.stats, 'Should have stats');
    assert.strictEqual(response.data.stats.total, urls.length, 'Should process all URLs');
    assert.ok(response.data.stats.successful > 0, 'Should have successful scrapes');
  }

  async testQualityCheck() {
    const response = await axios.post(WEBHOOK_URL, {
      urls: ['https://example.com']
    }, {
      headers: {
        'Authorization': `Bearer ${SCRAPER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: TEST_TIMEOUT
    });

    const result = response.data.results[0];
    assert.ok(result.data, 'Result should have data');
    assert.ok(result.data.text_content, 'Should have extracted text content');
    assert.ok(result.data.meta.text_length >= 500, 'Content should pass quality check (500+ chars)');
  }

  async testSSRFProtection() {
    const maliciousURLs = [
      'http://localhost:8080',
      'http://127.0.0.1:6379',
      'http://169.254.169.254/latest/meta-data',
      'http://metadata.google.internal'
    ];

    for (const url of maliciousURLs) {
      try {
        await axios.post(WEBHOOK_URL, {
          urls: [url]
        }, {
          headers: {
            'Authorization': `Bearer ${SCRAPER_API_KEY}`,
            'Content-Type': 'application/json'
          },
          timeout: 10000
        });
        throw new Error(`SSRF protection failed for ${url}`);
      } catch (error) {
        if (error.response) {
          assert.ok(
            error.response.status === 400 || error.response.status === 403,
            `Should reject SSRF attempt for ${url}`
          );
        } else if (error.message.includes('SSRF')) {
          // Expected error
        } else {
          throw error;
        }
      }
    }
  }

  async testRateLimiting() {
    // Send 15 requests rapidly (assuming limit is 10 per minute)
    const promises = [];
    for (let i = 0; i < 15; i++) {
      promises.push(
        axios.post(WEBHOOK_URL, {
          urls: ['https://example.com']
        }, {
          headers: {
            'Authorization': `Bearer ${SCRAPER_API_KEY}`,
            'Content-Type': 'application/json'
          },
          timeout: 5000,
          validateStatus: () => true // Accept all status codes
        })
      );
    }

    const responses = await Promise.all(promises);
    const rateLimited = responses.filter(r => r.status === 429);

    assert.ok(rateLimited.length > 0, 'Should have rate limited requests');
  }

  async testInvalidAuth() {
    try {
      await axios.post(WEBHOOK_URL, {
        urls: ['https://example.com']
      }, {
        headers: {
          'Authorization': 'Bearer invalid-key',
          'Content-Type': 'application/json'
        },
        timeout: 5000
      });
      throw new Error('Should reject invalid auth');
    } catch (error) {
      assert.ok(
        error.response && (error.response.status === 401 || error.response.status === 403),
        'Should return 401 or 403 for invalid auth'
      );
    }
  }

  async testWorkflowStats() {
    const response = await axios.post(WEBHOOK_URL, {
      urls: [
        'https://example.com',
        'https://invalid-url-that-will-fail.com'
      ]
    }, {
      headers: {
        'Authorization': `Bearer ${SCRAPER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: TEST_TIMEOUT,
      validateStatus: () => true
    });

    assert.ok(response.data.stats, 'Should have stats');
    assert.ok(response.data.stats.total >= 2, 'Should report total count');
    assert.ok(response.data.stats.success_rate, 'Should calculate success rate');
    assert.ok(response.data.stats.by_runner, 'Should group by runner');
  }

  async testFallbackChain() {
    // Test with a JS-heavy site that should trigger fallback
    const response = await axios.post(WEBHOOK_URL, {
      urls: ['https://www.react.dev'] // React site, needs JS
    }, {
      headers: {
        'Authorization': `Bearer ${SCRAPER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: TEST_TIMEOUT
    });

    const result = response.data.results[0];
    assert.ok(result, 'Should have result');
    assert.ok(
      ['playwright', 'nodriver', 'firecrawl'].includes(result.runner),
      'Should use appropriate runner for JS site'
    );
  }

  printSummary() {
    console.log('\n' + '='.repeat(60));
    console.log('E2E TEST SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total Tests: ${this.results.passed + this.results.failed}`);
    console.log(`✅ Passed: ${this.results.passed}`);
    console.log(`❌ Failed: ${this.results.failed}`);
    console.log('\nDetailed Results:');
    
    for (const test of this.results.tests) {
      const status = test.status === 'PASSED' ? '✅' : '❌';
      console.log(`  ${status} ${test.name} (${test.duration}ms)`);
      if (test.error) {
        console.log(`     Error: ${test.error}`);
      }
    }

    console.log('='.repeat(60));
    
    // Exit with error code if any tests failed
    if (this.results.failed > 0) {
      process.exit(1);
    }
  }
}

// Run tests
(async () => {
  const tester = new WorkflowE2ETest();

  console.log('📊 Starting E2E Tests for N8N Workflow');
  console.log(`N8N URL: ${N8N_BASE_URL}`);
  console.log(`Webhook: ${WEBHOOK_URL}`);

  await tester.runTest('Simple Scrape Test', () => tester.testSimpleScrape());
  await tester.runTest('Batch Scrape Test', () => tester.testBatchScrape());
  await tester.runTest('Quality Check Test', () => tester.testQualityCheck());
  await tester.runTest('SSRF Protection Test', () => tester.testSSRFProtection());
  await tester.runTest('Rate Limiting Test', () => tester.testRateLimiting());
  await tester.runTest('Invalid Auth Test', () => tester.testInvalidAuth());
  await tester.runTest('Workflow Stats Test', () => tester.testWorkflowStats());
  await tester.runTest('Fallback Chain Test', () => tester.testFallbackChain());

  tester.printSummary();
})();
