-- name: top_pages
SELECT url, COUNT(*) AS clicks, COUNT(DISTINCT ip) AS unique_visitors
FROM clickstream
GROUP BY url
ORDER BY clicks DESC
LIMIT 10;

-- name: daily_traffic
SELECT event_date, COUNT(*) AS clicks, COUNT(DISTINCT ip) AS unique_visitors
FROM clickstream
GROUP BY event_date
ORDER BY event_date;

-- name: top_pages_per_day
SELECT event_date, url, clicks, page_rank
FROM (
  SELECT event_date, url, COUNT(*) AS clicks,
         RANK() OVER (PARTITION BY event_date ORDER BY COUNT(*) DESC) AS page_rank
  FROM clickstream
  GROUP BY event_date, url
) ranked
WHERE page_rank <= 3
ORDER BY event_date, page_rank;

-- name: hourly_pattern
SELECT HOUR(event_ts) AS hour_of_day, COUNT(*) AS clicks
FROM clickstream
GROUP BY HOUR(event_ts)
ORDER BY hour_of_day;

-- name: traffic_by_section
SELECT section, COUNT(*) AS clicks
FROM clickstream
GROUP BY section
ORDER BY clicks DESC;

-- name: bot_candidates
SELECT ip, COUNT(*) AS requests, COUNT(DISTINCT url) AS distinct_pages
FROM clickstream
GROUP BY ip
ORDER BY requests DESC
LIMIT 10;

-- name: purchase_funnel
SELECT stage, clicks,
       ROUND(100.0 * clicks / MAX(CASE WHEN stage = 'products' THEN clicks END) OVER (), 1) AS pct_of_product_views
FROM (
  SELECT section AS stage, COUNT(*) AS clicks
  FROM clickstream
  WHERE section IN ('products', 'cart', 'checkout', 'payment', 'order-confirmation')
  GROUP BY section
) stages
ORDER BY clicks DESC;
