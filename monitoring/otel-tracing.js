// ✅ FIX #14: OpenTelemetry distributed tracing for Jaeger
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { trace, context, SpanStatusCode } = require('@opentelemetry/api');

class N8NTracing {
  constructor(config = {}) {
    this.serviceName = config.serviceName || 'n8n-scraper-workflow';
    this.jaegerEndpoint = config.jaegerEndpoint || process.env.JAEGER_ENDPOINT || 'http://jaeger:14268/api/traces';
    this.enabled = config.enabled !== false && process.env.OTEL_TRACING_ENABLED !== 'false';
    
    if (this.enabled) {
      this.setupTracing();
    }
  }

  setupTracing() {
    // Create resource
    const resource = Resource.default().merge(
      new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: this.serviceName,
        [SemanticResourceAttributes.SERVICE_VERSION]: '3.0.0',
        'deployment.environment': process.env.NODE_ENV || 'development'
      })
    );

    // Create provider
    const provider = new NodeTracerProvider({ resource });

    // Configure Jaeger exporter
    const jaegerExporter = new JaegerExporter({
      endpoint: this.jaegerEndpoint,
    });

    // Add span processor
    provider.addSpanProcessor(new BatchSpanProcessor(jaegerExporter, {
      maxQueueSize: 100,
      maxExportBatchSize: 10,
      scheduledDelayMillis: 500,
    }));

    // Register provider
    provider.register();

    // Register instrumentations
    registerInstrumentations({
      instrumentations: [
        new HttpInstrumentation({
          requestHook: (span, request) => {
            span.setAttribute('http.request.id', Date.now());
          },
        }),
        new ExpressInstrumentation(),
      ],
    });

    this.tracer = trace.getTracer(this.serviceName);
    console.log(`✅ OpenTelemetry tracing initialized (Jaeger: ${this.jaegerEndpoint})`);
  }

  // Wrapper for N8N workflow execution
  async traceWorkflowExecution(workflowName, executionId, fn) {
    if (!this.enabled) {
      return await fn();
    }

    return await this.tracer.startActiveSpan(`workflow.${workflowName}`, async (span) => {
      span.setAttribute('workflow.name', workflowName);
      span.setAttribute('workflow.execution_id', executionId);
      span.setAttribute('workflow.start_time', new Date().toISOString());

      try {
        const result = await fn();
        span.setAttribute('workflow.status', 'success');
        span.setAttribute('workflow.result_count', result?.length || 0);
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        span.setAttribute('workflow.status', 'failed');
        span.setAttribute('workflow.error', error.message);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        span.recordException(error);
        throw error;
      } finally {
        span.end();
      }
    });
  }

  // Trace scraping operation
  async traceScrape(url, runner, fn) {
    if (!this.enabled) {
      return await fn();
    }

    return await this.tracer.startActiveSpan(`scrape.${runner}`, async (span) => {
      span.setAttribute('scrape.url', url);
      span.setAttribute('scrape.runner', runner);
      span.setAttribute('scrape.start_time', Date.now());

      try {
        const result = await fn();
        span.setAttribute('scrape.success', result.success);
        span.setAttribute('scrape.content_length', result.data?.text_content?.length || 0);
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        span.setAttribute('scrape.success', false);
        span.setAttribute('scrape.error', error.message);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        span.recordException(error);
        throw error;
      } finally {
        span.end();
      }
    });
  }

  // Trace GitHub Actions polling
  async traceGitHubPolling(batchId, fn) {
    if (!this.enabled) {
      return await fn();
    }

    return await this.tracer.startActiveSpan('github.polling', async (span) => {
      span.setAttribute('github.batch_id', batchId);
      span.setAttribute('github.start_time', Date.now());

      try {
        const result = await fn();
        span.setAttribute('github.attempts', result.attempts || 0);
        span.setAttribute('github.artifact_id', result.artifactId || '');
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        span.setAttribute('github.error', error.message);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        span.recordException(error);
        throw error;
      } finally {
        span.end();
      }
    });
  }

  // Trace Firecrawl fallback
  async traceFirecrawlFallback(url, fn) {
    if (!this.enabled) {
      return await fn();
    }

    return await this.tracer.startActiveSpan('firecrawl.fallback', async (span) => {
      span.setAttribute('firecrawl.url', url);
      span.setAttribute('firecrawl.start_time', Date.now());

      try {
        const result = await fn();
        span.setAttribute('firecrawl.attempts', result.attempts || 0);
        span.setAttribute('firecrawl.success', result.success);
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        span.setAttribute('firecrawl.error', error.message);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        span.recordException(error);
        throw error;
      } finally {
        span.end();
      }
    });
  }

  // Trace quality check
  traceQualityCheck(url, passed, reason = '') {
    if (!this.enabled) return;

    const span = this.tracer.startSpan('quality_check');
    span.setAttribute('quality.url', url);
    span.setAttribute('quality.passed', passed);
    span.setAttribute('quality.reason', reason);
    span.setStatus({ code: SpanStatusCode.OK });
    span.end();
  }

  // Manual span creation for custom operations
  createSpan(name, attributes = {}) {
    if (!this.enabled) return null;

    const span = this.tracer.startSpan(name);
    for (const [key, value] of Object.entries(attributes)) {
      span.setAttribute(key, value);
    }
    return span;
  }
}

// Singleton instance
let tracingInstance = null;

function getTracing(config) {
  if (!tracingInstance) {
    tracingInstance = new N8NTracing(config);
  }
  return tracingInstance;
}

// Example usage in N8N Code Node:
/*
const { getTracing } = require('./monitoring/otel-tracing');
const tracing = getTracing();

// Trace entire workflow
const result = await tracing.traceWorkflowExecution(
  'smart-web-scraper',
  this.getExecutionId(),
  async () => {
    // Trace individual scrape
    const scrapeResult = await tracing.traceScrape(
      'https://example.com',
      'playwright',
      async () => {
        // ... scraping logic ...
        return { success: true, data: {...} };
      }
    );
    
    return scrapeResult;
  }
);
*/

module.exports = {
  N8NTracing,
  getTracing
};
