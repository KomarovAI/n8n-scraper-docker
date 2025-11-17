// ✅ FIX #13: Prometheus metrics for workflow success, latency, errors
const promClient = require('prom-client');

// Create a Registry
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({ register });

// Custom metrics for N8N workflow
const workflowExecutions = new promClient.Counter({
  name: 'n8n_workflow_executions_total',
  help: 'Total number of workflow executions',
  labelNames: ['workflow_name', 'status', 'runner'],
  registers: [register]
});

const workflowDuration = new promClient.Histogram({
  name: 'n8n_workflow_duration_seconds',
  help: 'Workflow execution duration in seconds',
  labelNames: ['workflow_name', 'runner'],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 30, 60, 120, 300],
  registers: [register]
});

const scrapeRequests = new promClient.Counter({
  name: 'n8n_scrape_requests_total',
  help: 'Total number of scrape requests',
  labelNames: ['runner', 'status'],
  registers: [register]
});

const scrapeLatency = new promClient.Histogram({
  name: 'n8n_scrape_latency_seconds',
  help: 'Scrape request latency in seconds',
  labelNames: ['runner'],
  buckets: [0.5, 1, 2, 5, 10, 30, 60],
  registers: [register]
});

const qualityCheckResults = new promClient.Counter({
  name: 'n8n_quality_check_results_total',
  help: 'Quality check results',
  labelNames: ['passed', 'reason'],
  registers: [register]
});

const githubActionPolling = new promClient.Histogram({
  name: 'n8n_github_action_polling_seconds',
  help: 'GitHub Actions polling duration in seconds',
  labelNames: ['status'],
  buckets: [10, 30, 60, 120, 300, 600],
  registers: [register]
});

const firecrawlFallback = new promClient.Counter({
  name: 'n8n_firecrawl_fallback_total',
  help: 'Firecrawl fallback invocations',
  labelNames: ['status', 'attempts'],
  registers: [register]
});

const rateLimitExceeded = new promClient.Counter({
  name: 'n8n_rate_limit_exceeded_total',
  help: 'Rate limit exceeded events',
  labelNames: ['client_ip'],
  registers: [register]
});

const circuitBreakerState = new promClient.Gauge({
  name: 'n8n_circuit_breaker_state',
  help: 'Circuit breaker state (0=CLOSED, 1=HALF_OPEN, 2=OPEN)',
  labelNames: ['breaker_name'],
  registers: [register]
});

// Helper functions for N8N Code Nodes
function recordWorkflowExecution(workflowName, status, runner = 'unknown') {
  workflowExecutions.inc({ workflow_name: workflowName, status, runner });
}

function recordWorkflowDuration(workflowName, durationSeconds, runner = 'unknown') {
  workflowDuration.observe({ workflow_name: workflowName, runner }, durationSeconds);
}

function recordScrapeRequest(runner, status) {
  scrapeRequests.inc({ runner, status });
}

function recordScrapeLatency(runner, latencySeconds) {
  scrapeLatency.observe({ runner }, latencySeconds);
}

function recordQualityCheck(passed, reason = 'unknown') {
  qualityCheckResults.inc({ passed: passed ? 'true' : 'false', reason });
}

function recordGitHubPolling(durationSeconds, status) {
  githubActionPolling.observe({ status }, durationSeconds);
}

function recordFirecrawlFallback(status, attempts) {
  firecrawlFallback.inc({ status, attempts: attempts.toString() });
}

function recordRateLimitExceeded(clientIP) {
  rateLimitExceeded.inc({ client_ip: clientIP });
}

function setCircuitBreakerState(breakerName, state) {
  const stateValue = state === 'CLOSED' ? 0 : state === 'HALF_OPEN' ? 1 : 2;
  circuitBreakerState.set({ breaker_name: breakerName }, stateValue);
}

// Metrics endpoint for Prometheus scraping
function getMetricsHandler() {
  return async (req, res) => {
    res.setHeader('Content-Type', register.contentType);
    res.end(await register.metrics());
  };
}

// Express middleware (if using Express)
function metricsMiddleware(app) {
  app.get('/metrics', getMetricsHandler());
}

// Example usage in N8N Code Node:
/*
const { recordWorkflowExecution, recordWorkflowDuration } = require('./monitoring/prometheus-metrics');

const startTime = Date.now();
try {
  // ... workflow logic ...
  recordWorkflowExecution('smart-web-scraper', 'success', 'playwright');
} catch (error) {
  recordWorkflowExecution('smart-web-scraper', 'failed', 'playwright');
} finally {
  const duration = (Date.now() - startTime) / 1000;
  recordWorkflowDuration('smart-web-scraper', duration, 'playwright');
}
*/

module.exports = {
  register,
  recordWorkflowExecution,
  recordWorkflowDuration,
  recordScrapeRequest,
  recordScrapeLatency,
  recordQualityCheck,
  recordGitHubPolling,
  recordFirecrawlFallback,
  recordRateLimitExceeded,
  setCircuitBreakerState,
  getMetricsHandler,
  metricsMiddleware
};
