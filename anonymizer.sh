#!/bin/bash

# Exit on error
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
RULES_DIR="$CONFIG_DIR/rules"
DUMPS_DIR="$SCRIPT_DIR/dumps"
LOCAL_PORT="15432"
ANON_PASSWORD="strong_password_here"

source $SCRIPT_DIR/lib/rules_processor.sh

# Function to clean up resources
cleanup() {
    echo "Cleaning up resources..."
    docker stop pg_anonymizer >/dev/null 2>&1 || true
    docker rm pg_anonymizer >/dev/null 2>&1 || true
    rm -f original_dump.sql
}

# Function to create dumps directory if it doesn't exist
create_dumps_dir() {
    if [ ! -d "$DUMPS_DIR" ]; then
        echo "Creating dumps directory..."
        mkdir -p "$DUMPS_DIR"
    fi
}

# Function to generate output filename
generate_output_filename() {
    local db_name=$1
    local datetime=$(date '+%Y%m%d_%H%M%S')
    echo "${DUMPS_DIR}/${datetime}_${db_name}_dump.sql"
}

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    local port=$1
    local max_attempts=30
    local attempt=1

    echo "Waiting for PostgreSQL to initialize..."
    while [ $attempt -le $max_attempts ]; do
        if PGPASSWORD=$ANON_PASSWORD psql -h "127.0.0.1" -p "$port" -U "postgres" -d "postgres" -c '\q' >/dev/null 2>&1; then
            echo "PostgreSQL is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    echo "Error: PostgreSQL failed to start after $max_attempts seconds"
    return 1
}

# Function to check port availability
check_port_available() {
    ! lsof -Pi :"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

# Function to find available port
find_available_port() {
    local port=${1:-15432}
    while ! check_port_available $port; do
        port=$((port + 1))
    done
    echo $port
}

# Function to load configuration
load_config() {
    local config_file=$1
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file not found: $config_file"
        exit 1
    fi

    # Read the YAML file line by line
    while IFS=':' read -r key value; do
        # Remove leading/trailing whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
        
        case "$key" in
            "host") DB_HOST="$value" ;;
            "port") DB_PORT="$value" ;;
            "database") DB_NAME="$value" ;;
            "user") DB_USER="$value" ;;
            "password") DB_PASSWORD="$value" ;;
        esac
    done < "$config_file"

    # Validate configuration
    if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
        echo "Error: Missing required configuration values"
        echo "Required fields: host, port, database, user, password"
        exit 1
    fi

    echo "Loaded database configuration:"
    echo "Host: $DB_HOST"
    echo "Port: $DB_PORT"
    echo "Database: $DB_NAME"
    echo "User: $DB_USER"
}

# Main function
main() {
    local db_config="$1"

    # Load configuration
    load_config "$db_config"

    # Create dumps directory
    create_dumps_dir

    # Generate output filename
    local output_file=$(generate_output_filename "$DB_NAME")
    echo "Output will be saved to: $output_file"

    # Find available port
    LOCAL_PORT=$(find_available_port $LOCAL_PORT)
    echo "Using port $LOCAL_PORT for anonymizer container..."

    # Start anonymizer container
    echo "Starting PostgreSQL Anonymizer container..."
    docker run -d \
        --name pg_anonymizer \
        -e POSTGRES_PASSWORD=$ANON_PASSWORD \
        -p $LOCAL_PORT:5432 \
        registry.gitlab.com/dalibo/postgresql_anonymizer:stable

    # Wait for container to be ready
    wait_for_postgres $LOCAL_PORT

    # Dump original database
    echo "Dumping original database..."
    PGPASSWORD=$DB_PASSWORD pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --no-owner \
        --no-acl > original_dump.sql

    if [ ! -s original_dump.sql ]; then
        echo "Error: Database dump is empty"
        exit 1
    fi

    # Create and prepare anonymization database
    echo "Creating anonymization database..."
    PGPASSWORD=$ANON_PASSWORD psql \
        -h "127.0.0.1" \
        -p "$LOCAL_PORT" \
        -U "postgres" \
        -d "postgres" \
        -c "DROP DATABASE IF EXISTS ${DB_NAME}_anon;"

    PGPASSWORD=$ANON_PASSWORD psql \
        -h "127.0.0.1" \
        -p "$LOCAL_PORT" \
        -U "postgres" \
        -d "postgres" \
        -c "CREATE DATABASE ${DB_NAME}_anon;"

    # Import the original dump
    echo "Importing original database..."
    PGPASSWORD=$ANON_PASSWORD psql \
        -h "127.0.0.1" \
        -p "$LOCAL_PORT" \
        -U "postgres" \
        -d "${DB_NAME}_anon" \
        < original_dump.sql

    # Set up anonymization
    echo "Setting up anonymization..."
    PGPASSWORD=$ANON_PASSWORD psql \
        -h "127.0.0.1" \
        -p "$LOCAL_PORT" \
        -U "postgres" \
        -d "${DB_NAME}_anon" << EOF
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.init();

-- Create anonymization role
DROP ROLE IF EXISTS dump_anon;
CREATE ROLE dump_anon LOGIN PASSWORD 'anon_pass';
ALTER ROLE dump_anon SET anon.transparent_dynamic_masking = True;
SECURITY LABEL FOR anon ON ROLE dump_anon IS 'MASKED';

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO dump_anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dump_anon;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO dump_anon;
EOF

    # Process rules
    process_rules "$RULES_DIR" "$DB_NAME" "$LOCAL_PORT"

    # Create final anonymized dump
    echo "Creating anonymized dump..."
    PGPASSWORD=anon_pass pg_dump \
        -h "127.0.0.1" \
        -p "$LOCAL_PORT" \
        -U "dump_anon" \
        -d "${DB_NAME}_anon" \
        --no-security-labels \
        --no-owner \
        --no-acl \
        > "$output_file"

    if [ ! -s "$output_file" ]; then
        echo "Error: Anonymized dump is empty"
        exit 1
    fi

    echo "Process completed! Anonymized dump is available in: $output_file"
}

# Parse command line arguments
while getopts "d:" opt; do
    case $opt in
        d) DB_CONFIG="$OPTARG";;
        *) 
            echo "Usage: $0 -d <database_config>"
            exit 1
            ;;
    esac
done

if [ -z "$DB_CONFIG" ]; then
    echo "Usage: $0 -d <database_config>"
    exit 1
fi

# Set up cleanup trap
trap cleanup EXIT

# Run main function
main "$DB_CONFIG"