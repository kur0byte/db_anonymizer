#!/bin/bash

# Function to dump original database
dump_original_db() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local db_name=$5
    local output_file=$6

    echo "Dumping original database..."
    PGPASSWORD=$password pg_dump \
        -h "$host" \
        -p "$port" \
        -U "$user" \
        -d "$db_name" \
        --no-owner \
        --no-acl > "$output_file"

    if [ ! -s "$output_file" ]; then
        echo "Error: Database dump is empty"
        return 1
    fi
    return 0
}

# Function to create anonymized dump
create_anonymized_dump() {
    local host=$1
    local port=$2
    local db_name=$3
    local output_file=$4
    
    echo "Creating anonymized dump..."
    PGPASSWORD=anon_pass pg_dump \
        -h "$host" \
        -p "$port" \
        -U "dump_anon" \
        -d "${db_name}_anon" \
        --no-security-labels \
        --no-owner \
        --no-acl \
        > "$output_file"

    if [ ! -s "$output_file" ]; then
        echo "Error: Anonymized dump is empty"
        return 1
    fi
    return 0
}

# Function to import dump into anonymization database
import_dump() {
    local host=$1
    local port=$2
    local password=$3
    local db_name=$4
    local input_file=$5

    echo "Importing original database..."
    PGPASSWORD=$password psql \
        -h "$host" \
        -p "$port" \
        -U "postgres" \
        -d "${db_name}_anon" \
        < "$input_file"
    
    return $?
}