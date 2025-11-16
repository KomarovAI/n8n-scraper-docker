# API Reference

## Scrape Endpoint

### POST /webhook/scrape

Scrape a web page with intelligent runner selection.

#### Headers

```
X-API-Key: your-secret-key
Content-Type: application/json
```

#### Request Body

```json
{
  "url": "https://example.com",
  "selector": "article",
  "waitFor": ".content"
}
```

**Parameters:**

- `url` (required): Target URL to scrape
- `selector` (optional): CSS selector for content extraction (default: "body")
- `waitFor` (optional): CSS selector to wait for before extraction

#### Response

```json
{
  "success": true,
  "url": "https://example.com",
  "content": "Extracted content...",
  "metadata": {
    "runner": "playwright",
    "size": 12345,
    "processingTime": 2340
  },
  "timestamp": "2025-11-16T20:00:00Z"
}
```

#### Error Response

```json
{
  "success": false,
  "error": "SSRF detected - blocked host",
  "timestamp": "2025-11-16T20:00:00Z"
}
```

#### Status Codes

- `200` - Success
- `400` - Bad Request (invalid input)
- `401` - Unauthorized (invalid API key)
- `500` - Internal Server Error
- `504` - Gateway Timeout (scraping timeout)

## Rate Limits

- 100 requests per minute per API key
- Burst: 20 requests per second
