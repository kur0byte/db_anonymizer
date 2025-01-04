#!/bin/bash

# Exit on error
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
RULES_DIR="$CONFIG_DIR/rules"
LOCAL_PORT="15432"
ANON_PASSWORD="strong_password_here"

# Source required libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/rules_processor.sh"
source "$SCRIPT_DIR/lib/anonymizer_setup.sh"
source "$SCRIPT_DIR/lib/dumper.sh"

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

# Function to clean up resources
cleanup() {
    echo "Cleaning up resources..."
    docker stop pg_anonymizer >/dev/null 2>&1 || true
    docker rm pg_anonymizer >/dev/null 2>&1 || true
}

# Function to process dump file
process_dump() {
    local input_dump=$1
    local output_file=$2
    local rules_dir=$3

    if [ ! -f "$input_dump" ]; then
        echo "Error: Input dump file not found: $input_dump"
        exit 1
    fi

    # Find available port
    LOCAL_PORT=$(find_available_port $LOCAL_PORT)
    echo "Using port $LOCAL_PORT for anonymizer container..."
    
    # Start anonymizer container
    if ! start_anonymizer_container "$LOCAL_PORT" "$ANON_PASSWORD"; then
        echo "Error: Failed to start anonymizer container"
        exit 1
    fi
    
    # Wait for container to be ready
    wait_for_postgres "$LOCAL_PORT"
    
    # Create temporary database for anonymization
    local db_name="dump_$(date +%s)"
    if ! init_anon_db "127.0.0.1" "$LOCAL_PORT" "$ANON_PASSWORD" "$db_name"; then
        echo "Error: Failed to initialize anonymization database"
        exit 1
    fi
    
    # Import the dump
    echo "Importing dump file..."
    if ! import_dump "127.0.0.1" "$LOCAL_PORT" "$ANON_PASSWORD" "$db_name" "$input_dump"; then
        echo "Error: Failed to import dump file"
        exit 1
    fi
    
    # Setup anonymization environment
    if ! setup_anon_environment "127.0.0.1" "$LOCAL_PORT" "$ANON_PASSWORD" "$db_name"; then
        echo "Error: Failed to setup anonymization environment"
        exit 1
    fi
    
    # Process anonymization rules
    if ! process_rules "$rules_dir" "$db_name" "$LOCAL_PORT"; then
        echo "Error: Failed to process anonymization rules"
        exit 1
    fi
    
    # Create anonymized dump
    if ! create_anonymized_dump "127.0.0.1" "$LOCAL_PORT" "$db_name" "$output_file"; then
        echo "Error: Failed to create anonymized dump"
        exit 1
    fi
    
    echo "Anonymization complete! Output saved to: $output_file"
}

# Print help message
print_help() {
    echo "Database Dump Anonymizer"
    echo "Usage: $0 -i <input_dump> -o <output_file> [-r <rules_dir>]"
    echo
    echo "Options:"
    echo "  -i <input_dump>    Input dump file path"
    echo "  -o <output_file>   Output file path"
    echo "  -r <rules_dir>     Rules directory (default: config/rules)"
    echo "  -h                 Show this help message"
}

# Main script logic
main() {
    local input_dump=""
    local output_file=""
    local custom_rules_dir=""

    # Parse command line arguments
    while getopts "i:o:r:h" opt; do
        case $opt in
            i) input_dump="$OPTARG" ;;
            o) output_file="$OPTARG" ;;
            r) custom_rules_dir="$OPTARG" ;;
            h) print_help; exit 0 ;;
            *) print_help; exit 1 ;;
        esac
    done

    # Validate required parameters
    if [ -z "$input_dump" ] || [ -z "$output_file" ]; then
        echo "Error: Missing required parameters"
        print_help
        exit 1
    fi

    # Process the dump file
    process_dump "$input_dump" "$output_file" "${custom_rules_dir:-$RULES_DIR}"
}

# Set up cleanup trap
trap cleanup EXIT

# Run main function
main "$@"