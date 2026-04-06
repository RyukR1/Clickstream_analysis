-- Hive Script: create_table.hql
-- Purpose: Create external table for processed clickstream data
-- This allows us to query cleaned logs using SQL-like syntax

-- Drop table if exists (for fresh runs)
DROP TABLE IF EXISTS clickstream;

-- Create external table pointing to processed data in HDFS
CREATE EXTERNAL TABLE clickstream (
    ip STRING COMMENT 'IP address of the visitor',
    visit_date STRING COMMENT 'Date of the visit (DD/Mon/YYYY)',
    url STRING COMMENT 'HTTP request/URL visited'
)
COMMENT 'Clickstream data from Apache Flume and Pig pipeline'
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/root/clickstream/processed/';

-- Verify the table was created successfully
SHOW TABLES;
DESCRIBE clickstream;
