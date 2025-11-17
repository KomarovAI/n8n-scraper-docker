-- ✅ FIX #7: PostgreSQL индексы и UNIQUE constraint на url
-- Migration: 001_create_scraped_data_table.sql
-- Description: Create scraped_data table with proper indexes and constraints
-- Author: KomarovAI
-- Date: 2025-11-18

-- Create main scraped_data table
CREATE TABLE IF NOT EXISTS scraped_data (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,  -- ✅ UNIQUE constraint for ON CONFLICT
  title TEXT,
  content TEXT,
  metadata JSONB,
  runner VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_scraped_url ON scraped_data(url);
CREATE INDEX IF NOT EXISTS idx_scraped_runner ON scraped_data(runner);
CREATE INDEX IF NOT EXISTS idx_scraped_created ON scraped_data(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scraped_updated ON scraped_data(updated_at DESC);

-- JSONB GIN index for metadata queries
CREATE INDEX IF NOT EXISTS idx_scraped_metadata ON scraped_data USING GIN (metadata);

-- Partial index for recent data
CREATE INDEX IF NOT EXISTS idx_scraped_recent ON scraped_data(created_at DESC) 
WHERE created_at > NOW() - INTERVAL '30 days';

-- Add comment
COMMENT ON TABLE scraped_data IS 'Stores scraped web content with metadata';
COMMENT ON COLUMN scraped_data.url IS 'Unique URL of scraped page';
COMMENT ON COLUMN scraped_data.metadata IS 'JSONB metadata (text_length, links_count, etc.)';
COMMENT ON COLUMN scraped_data.runner IS 'Scraper engine used (http_basic, playwright, nodriver, firecrawl)';

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_scraped_data_updated_at BEFORE UPDATE
ON scraped_data FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Create stats view
CREATE OR REPLACE VIEW scraped_data_stats AS
SELECT 
  runner,
  COUNT(*) as total_count,
  COUNT(DISTINCT url) as unique_urls,
  AVG((metadata->>'text_length')::int) as avg_text_length,
  MAX(created_at) as last_scraped
FROM scraped_data
GROUP BY runner;

COMMENT ON VIEW scraped_data_stats IS 'Statistics by scraper runner';
