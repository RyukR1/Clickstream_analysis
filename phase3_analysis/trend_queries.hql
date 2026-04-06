-- Hive Script: trend_queries.hql
-- Purpose: Analyze clickstream data to find trends
-- These queries help identify the most visited pages and popular content

-- ============================================================
-- Query 1: Top 5 Most Visited Pages (Overall)
-- ============================================================
-- Find the pages that receive the most clicks
SELECT url, COUNT(*) as click_count
FROM clickstream
GROUP BY url
ORDER BY click_count DESC
LIMIT 5;

-- ============================================================
-- Query 2: Top 10 Most Visited Pages (Overall)
-- ============================================================
SELECT url, COUNT(*) as click_count
FROM clickstream
GROUP BY url
ORDER BY click_count DESC
LIMIT 10;

-- ============================================================
-- Query 3: Daily Trend Analysis
-- ============================================================
-- See how the traffic varies by date
SELECT visit_date, COUNT(*) as daily_clicks
FROM clickstream
GROUP BY visit_date
ORDER BY visit_date DESC;

-- ============================================================
-- Query 4: Top Pages by Date (Time-Series)
-- ============================================================
-- Show the most popular pages for each day
SELECT visit_date, url, COUNT(*) as daily_page_count
FROM clickstream
GROUP BY visit_date, url
ORDER BY visit_date DESC, daily_page_count DESC;

-- ============================================================
-- Query 5: Unique IPs (Visitor Count)
-- ============================================================
-- Estimate number of unique visitors
SELECT COUNT(DISTINCT ip) as unique_visitors
FROM clickstream;

-- ============================================================
-- Query 6: User Behavior: Pages by Unique IPs
-- ============================================================
-- See how many unique IPs visited each page
SELECT url, COUNT(DISTINCT ip) as unique_visitors
FROM clickstream
GROUP BY url
ORDER BY unique_visitors DESC
LIMIT 10;

-- ============================================================
-- Query 7: Traffic by IP (Top Visitors)
-- ============================================================
-- Identify which IPs generate the most traffic (bots, frequent visitors)
SELECT ip, COUNT(*) as page_visits
FROM clickstream
GROUP BY ip
ORDER BY page_visits DESC
LIMIT 10;

-- ============================================================
-- Query 8: URL Pattern Analysis
-- ============================================================
-- Extract page names from URLs to group similar pages
-- Example: /products/laptop and /products/phone both count as "products" traffic
SELECT 
    CASE 
        WHEN url LIKE '%login%' THEN 'Login Page'
        WHEN url LIKE '%product%' THEN 'Product Pages'
        WHEN url LIKE '%cart%' THEN 'Shopping Cart'
        WHEN url LIKE '%checkout%' THEN 'Checkout'
        WHEN url LIKE '%search%' THEN 'Search'
        ELSE 'Other'
    END as page_category,
    COUNT(*) as clicks
FROM clickstream
GROUP BY 
    CASE 
        WHEN url LIKE '%login%' THEN 'Login Page'
        WHEN url LIKE '%product%' THEN 'Product Pages'
        WHEN url LIKE '%cart%' THEN 'Shopping Cart'
        WHEN url LIKE '%checkout%' THEN 'Checkout'
        WHEN url LIKE '%search%' THEN 'Search'
        ELSE 'Other'
    END
ORDER BY clicks DESC;
