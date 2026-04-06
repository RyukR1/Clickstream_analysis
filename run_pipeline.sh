#!/bin/bash

# Website Clickstream Pipeline - Complete Automation Script
# This script generates data and runs the entire pipeline automatically
# Usage: ./run_pipeline.sh

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/clickstream"
LOG_DIR="$PROJECT_DIR/logs"
HDFS_RAW="/user/root/clickstream/raw"
HDFS_PROCESSED="/user/root/clickstream/processed"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Main pipeline execution
main() {
    print_header "🚀 CLICKSTREAM PIPELINE STARTED"
    echo "Timestamp: $TIMESTAMP"
    
    # Step 1: Generate Sample Data
    print_header "STEP 1: GENERATING SAMPLE DATA"
    generate_logs
    
    # Step 2: Upload to HDFS
    print_header "STEP 2: UPLOADING TO HDFS"
    upload_to_hdfs
    
    # Step 3: Clean Old Processed Data
    print_header "STEP 3: CLEANING OLD DATA"
    cleanup_hdfs
    
    # Step 4: Run Pig ETL
    print_header "STEP 4: RUNNING PIG ETL (CLEANING)"
    run_pig_etl
    
    # Step 5: Create Hive Table
    print_header "STEP 5: CREATING HIVE TABLE"
    create_hive_table
    
    # Step 6: Run Analytics Queries
    print_header "STEP 6: RUNNING ANALYTICS QUERIES"
    run_hive_queries
    
    print_header "✅ PIPELINE COMPLETED SUCCESSFULLY"
}

# Step 1: Generate sample logs
generate_logs() {
    print_info "Generating 100 sample log entries..."
    
    python3 << 'PYTHON_EOF'
import random
from datetime import datetime, timedelta

# Configuration
NUM_LOGS = 100
OUTPUT_FILE = '/clickstream/logs/access.log'

# Realistic website pages and IPs
PAGES = [
    '/index.html',
    '/products/laptop',
    '/products/phone',
    '/products/tablet',
    '/cart',
    '/checkout',
    '/payment',
    '/order-confirmation',
    '/account',
    '/support',
    '/about',
    '/blog'
]

STATIC_ASSETS = [
    '/css/style.css',
    '/js/app.js',
    '/images/logo.png',
    '/images/banner.jpg',
    '/images/product1.jpg',
    '/images/product2.jpg'
]

IPS = [
    '192.168.1.100',
    '192.168.1.101',
    '192.168.1.102',
    '10.0.0.1',
    '172.16.0.50'
]

# Generate logs in Apache Common Log Format
with open(OUTPUT_FILE, 'w') as f:
    current_time = datetime(2026, 4, 6, 10, 0, 0)
    
    for i in range(NUM_LOGS):
        # 70% pages, 20% static assets, 10% 404 errors
        rand = random.random()
        
        if rand < 0.7:  # Real pages - 200 OK
            page = random.choice(PAGES)
            status = 200
        elif rand < 0.9:  # Static assets - 200 OK
            page = random.choice(STATIC_ASSETS)
            status = 200
        else:  # 404 errors
            page = '/admin/login.php'
            status = 404
        
        ip = random.choice(IPS)
        size = random.randint(1000, 50000)
        timestamp = current_time.strftime('%d/%b/%Y:%H:%M:%S +0000')
        
        # Apache Common Log Format
        log_entry = f'{ip} - - [{timestamp}] "GET {page} HTTP/1.1" {status} {size}\n'
        f.write(log_entry)
        
        # Increment time by 1-10 seconds
        current_time += timedelta(seconds=random.randint(1, 10))

print(f"Generated {NUM_LOGS} sample logs")
PYTHON_EOF
    
    if [ -f "$LOG_DIR/access.log" ]; then
        print_success "Logs generated: $LOG_DIR/access.log"
        wc -l "$LOG_DIR/access.log" | awk '{print "  Lines: " $1}'
    else
        print_error "Failed to generate logs"
        return 1
    fi
}

# Step 2: Upload logs to HDFS
upload_to_hdfs() {
    print_info "Uploading logs to HDFS..."
    
    # Create HDFS directory if not exists
    hdfs dfs -mkdir -p "$HDFS_RAW" 2>/dev/null || true
    
    # Upload log file
    hdfs dfs -put -f "$LOG_DIR/access.log" "$HDFS_RAW/" 2>/dev/null || true
    
    # Verify upload
    if hdfs dfs -test -f "$HDFS_RAW/access.log"; then
        print_success "Uploaded to HDFS: $HDFS_RAW/access.log"
        local_size=$(stat -f%z "$LOG_DIR/access.log" 2>/dev/null || stat -c%s "$LOG_DIR/access.log" 2>/dev/null)
        echo "  File size: $local_size bytes"
    else
        print_error "Failed to upload to HDFS"
        return 1
    fi
}

# Step 3: Clean old processed data
cleanup_hdfs() {
    print_info "Removing old processed data..."
    
    hdfs dfs -rm -r -f "$HDFS_PROCESSED" 2>/dev/null || true
    
    print_success "Cleaned old data from $HDFS_PROCESSED"
}

# Step 4: Run Pig ETL script
run_pig_etl() {
    print_info "Running Pig ETL script..."
    
    if [ -f "$PROJECT_DIR/phase2_cleaning/clean_logs.pig" ]; then
        pig -x local "$PROJECT_DIR/phase2_cleaning/clean_logs.pig" 2>&1 | tail -20
        
        if hdfs dfs -test -f "$HDFS_PROCESSED/part-m-00000"; then
            print_success "Pig ETL completed"
            local record_count=$(hdfs dfs -cat "$HDFS_PROCESSED/part-m-00000" 2>/dev/null | wc -l)
            echo "  Records in output: $record_count"
        else
            print_error "Pig ETL failed - no output found"
            return 1
        fi
    else
        print_error "Pig script not found"
        return 1
    fi
}

# Step 5: Create Hive table
create_hive_table() {
    print_info "Creating Hive table schema..."
    
    if [ -f "$PROJECT_DIR/phase3_analysis/create_table.hql" ]; then
        hive -hiveconf hive.metastore.uris=thrift://localhost:9083 \
             -f "$PROJECT_DIR/phase3_analysis/create_table.hql" 2>&1 | grep -E "OK|ERROR|Exception" || true
        
        print_success "Hive table created"
    else
        print_error "Hive table creation script not found"
        return 1
    fi
}

# Step 6: Run Hive analytics queries
run_hive_queries() {
    print_info "Running 8 analytics queries..."
    
    if [ -f "$PROJECT_DIR/phase3_analysis/trend_queries.hql" ]; then
        hive -hiveconf hive.metastore.uris=thrift://localhost:9083 \
             -f "$PROJECT_DIR/phase3_analysis/trend_queries.hql" 2>&1
        
        print_success "Analytics queries completed, results displayed above"
    else
        print_error "Trend queries script not found"
        return 1
    fi
}

# Run main pipeline
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: ./run_pipeline.sh [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo "  --generate      Only generate sample logs"
    echo "  --upload        Only upload logs to HDFS"
    echo "  --clean         Only run Pig cleaning"
    echo "  --analyze       Only run Hive analysis"
    echo ""
    echo "Without options, runs complete pipeline"
    exit 0
fi

# Handle specific steps
case "$1" in
    --generate)
        print_header "GENERATING LOGS ONLY"
        generate_logs
        ;;
    --upload)
        print_header "UPLOADING TO HDFS ONLY"
        upload_to_hdfs
        ;;
    --clean)
        print_header "CLEANING DATA ONLY"
        cleanup_hdfs && run_pig_etl
        ;;
    --analyze)
        print_header "RUNNING ANALYSIS ONLY"
        run_hive_queries
        ;;
    *)
        main
        ;;
esac

print_info "Pipeline execution completed at $(date '+%Y-%m-%d %H:%M:%S')"
