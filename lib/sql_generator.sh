#!/bin/bash

# Function to generate SQL for enabling anonymization
generate_init_sql() {
    cat << EOF
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
}

# Function to generate SQL for masking a specific column
generate_mask_sql() {
    local table=$1
    local column=$2
    local mask_function=$3
    
    echo "SECURITY LABEL FOR anon ON COLUMN $table.$column IS 'MASKED WITH FUNCTION $mask_function';"
}

# Function to generate SQL for database creation
generate_db_create_sql() {
    local db_name=$1
    cat << EOF
DROP DATABASE IF EXISTS ${db_name}_anon;
CREATE DATABASE ${db_name}_anon;
EOF
}

# Function to generate common masking functions
# generate_common_masks() {
#     cat << EOF
# -- Email masking
# CREATE OR REPLACE FUNCTION anon.mask_email(email text) 
# RETURNS text AS \$\$
# BEGIN
#     RETURN regexp_replace(email, '^(.)(.*?)(@.*$)', '\1****\3');
# END;
# \$\$ LANGUAGE plpgsql IMMUTABLE;

# -- Phone masking
# CREATE OR REPLACE FUNCTION anon.mask_phone(phone text) 
# RETURNS text AS \$\$
# BEGIN
#     RETURN regexp_replace(phone, '^(\d{3})\d+(\d{4})$', '\1-XXX-\2');
# END;
# \$\$ LANGUAGE plpgsql IMMUTABLE;

# -- Credit card masking
# CREATE OR REPLACE FUNCTION anon.mask_credit_card(cc text) 
# RETURNS text AS \$\$
# BEGIN
#     RETURN regexp_replace(cc, '^(\d{4})\d+(\d{4})$', '\1-XXXX-XXXX-\2');
# END;
# \$\$ LANGUAGE plpgsql IMMUTABLE;

# -- Address masking
# CREATE OR REPLACE FUNCTION anon.mask_address(address text) 
# RETURNS text AS \$\$
# BEGIN
#     RETURN 'XXXXX ' || split_part(address, ' ', -1);
# END;
# \$\$ LANGUAGE plpgsql IMMUTABLE;
# EOF
# }

# Function to generate SQL for checking table existence
generate_table_check_sql() {
    local table=$1
    cat << EOF
DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = '${table}'
    ) THEN
        RAISE EXCEPTION 'Table ${table} does not exist';
    END IF;
END
\$\$;
EOF
}

# Function to generate SQL for schema validation
generate_schema_validation_sql() {
    local table=$1
    local columns=("$@")
    local sql="SELECT column_name FROM information_schema.columns WHERE table_name = '${table}' AND column_name IN ("
    for column in "${columns[@]:1}"; do
        sql+="'$column',"
    done
    sql="${sql%,});"
    echo "$sql"
}