#!/bin/bash

# Function to initialize anonymization database
init_anon_db() {
    local host=$1
    local port=$2
    local password=$3
    local db_name=$4

    echo "Creating anonymization database..."
    PGPASSWORD=$password psql \
        -h "$host" \
        -p "$port" \
        -U "postgres" \
        -d "postgres" \
        -c "DROP DATABASE IF EXISTS ${db_name}_anon;"

    PGPASSWORD=$password psql \
        -h "$host" \
        -p "$port" \
        -U "postgres" \
        -d "postgres" \
        -c "CREATE DATABASE ${db_name}_anon;"
    
    return $?
}

# Function to setup anonymization extensions and roles
setup_anon_environment() {
    local host=$1
    local port=$2
    local password=$3
    local db_name=$4

    echo "Setting up anonymization..."
    PGPASSWORD=$password psql \
        -h "$host" \
        -p "$port" \
        -U "postgres" \
        -d "${db_name}_anon" << EOF
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
    
    return $?
}

# Function to start anonymizer container
start_anonymizer_container() {
    local port=$1
    local password=$2
    
    echo "Starting PostgreSQL Anonymizer container..."
    docker run -d \
        --name pg_anonymizer \
        -e POSTGRES_PASSWORD=$password \
        -p $port:5432 \
        registry.gitlab.com/dalibo/postgresql_anonymizer:stable
    
    return $?
}