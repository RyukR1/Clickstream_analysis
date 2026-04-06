-- Pig Script: clean_logs.pig
-- Purpose: Clean raw Apache/Nginx clickstream logs from HDFS
-- Removes failed requests (404s, 500s) and static assets (.jpg, .gif, .css, .js, .png)
-- 
-- Note: Before running this script, delete the processed directory:
--   hdfs dfs -rm -r hdfs://localhost:9000/user/root/clickstream/processed
-- Pig won't overwrite existing output directories.

-- Load raw logs from HDFS in Apache/Nginx Common Log Format
-- Format: IP - [timestamp] "REQUEST" status size
-- Use regex to extract fields from the log line
raw_data = LOAD 'hdfs://localhost:9000/user/root/clickstream/raw/' AS (line:chararray);

-- Parse using regex_extract to safely extract fields
-- Pattern: ^(\S+) - \[(.*?)\] "(\S+ \S+ \S+)" (\d+) (\d+)
raw_logs = FOREACH raw_data GENERATE
    REGEX_EXTRACT(line, '(\\S+)', 1) as ip,
    REGEX_EXTRACT(line, '\\[(.*?)\\]', 1) as timestamp,
    REGEX_EXTRACT(line, '"(.*?)"', 1) as request,
    (int)REGEX_EXTRACT(line, '(\\d+)\\s+(\\d+)$', 1) as status,
    (int)REGEX_EXTRACT(line, '(\\d+)\\s+(\\d+)$', 2) as size;

-- Filter out failed requests (status != 200) and static assets
cleaned_logs = FILTER raw_logs BY 
    status == 200 
    AND NOT (request MATCHES '.*\\.jpg.*')
    AND NOT (request MATCHES '.*\\.gif.*')
    AND NOT (request MATCHES '.*\\.css.*')
    AND NOT (request MATCHES '.*\\.js.*')
    AND NOT (request MATCHES '.*\\.png.*')
    AND NOT (request MATCHES '.*\\.ico.*')
    AND NOT (request MATCHES '.*favicon.*');

-- Keep ip, timestamp, and request fields needed for trend analysis
-- Note: timestamp format is DD/Mon/YYYY:HH:MM:SS +0000 (date is first 10 chars)
final_data = FOREACH cleaned_logs GENERATE 
    ip as ip,
    timestamp as visit_date,
    request as url;

-- Store processed data back to HDFS as CSV for Hive consumption
STORE final_data INTO 'hdfs://localhost:9000/user/root/clickstream/processed/' USING PigStorage(',');

-- Alternative: For debugging during development
-- DUMP final_data;
