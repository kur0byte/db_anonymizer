#!/bin/bash

# Function to process a single rule file
process_rule_file() {
    local rule_file=$1
    local db_name=$2
    local port=$3
    
    echo "Processing rule file: $rule_file"
    
    # Check if file exists and is not empty
    if [ ! -f "$rule_file" ] || [ ! -s "$rule_file" ]; then
        echo "Error: Rule file $rule_file does not exist or is empty"
        return 1
    fi
    
    # Read table name with better handling of whitespace and empty values
    local table=$(grep "^table:" "$rule_file" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$table" ]; then
        echo "Error: No table name found in $rule_file"
        return 1
    fi
    
    echo "Table: $table"
    
    # Verify table exists in database
    local table_exists
    table_exists=$(PGPASSWORD=$ANON_PASSWORD psql -h "127.0.0.1" -p "$port" -U "postgres" -d "${db_name}_anon" -tAc \
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$table');")
    
    if [ "$table_exists" != "t" ]; then
        echo "Warning: Table $table does not exist in database, skipping..."
        return 1
    fi
    
    # Read columns section
    local in_columns=false
    local columns=()
    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ "$line" = "columns:" ]; then
            in_columns=true
            continue
        elif [ "$in_columns" = true ] && [[ "$line" =~ ^- ]]; then
            # Extract column name, removing the leading dash and whitespace
            local column=$(echo "$line" | sed 's/^-[[:space:]]*//;s/[[:space:]]*$//')
            columns+=("$column")
        elif [ "$in_columns" = true ] && [[ ! "$line" =~ ^- ]] && [ ! -z "$line" ]; then
            break
        fi
    done < "$rule_file"
    
    # Process each column
    for column in "${columns[@]}"; do
        echo "Processing column: $column"
        
        # Check if column exists in table
        local column_exists
        column_exists=$(PGPASSWORD=$ANON_PASSWORD psql -h "127.0.0.1" -p "$port" -U "postgres" -d "${db_name}_anon" -tAc \
            "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = '$table' AND column_name = '$column');")
        
        if [ "$column_exists" != "t" ]; then
            echo "Warning: Column $column does not exist in table $table, skipping..."
            continue
        fi
        
        # Extract mask function
        local mask
        mask=$(grep -A50 "^mask_functions:" "$rule_file" | grep "^[[:space:]]*$column:" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ ! -z "$mask" ]; then
            echo "Applying mask: $mask"
            if PGPASSWORD=$ANON_PASSWORD psql -h "127.0.0.1" -p "$port" -U "postgres" -d "${db_name}_anon" -c \
                "SECURITY LABEL FOR anon ON COLUMN $table.$column IS 'MASKED WITH FUNCTION $mask';" > /dev/null 2>&1; then
                echo "Successfully masked $table.$column"
            else
                echo "Error: Failed to mask $table.$column"
            fi
        else
            echo "Warning: No mask function found for column $column"
        fi
    done
    
    return 0
}

# Function to process all rule files
process_rules() {
    local rules_dir=$1
    local db_name=$2
    local port=$3
    
    echo "Processing rules from directory: $rules_dir"
    
    if [ ! -d "$rules_dir" ]; then
        echo "Error: Rules directory not found at $rules_dir"
        return 1
    fi
    
    local rule_files=("$rules_dir"/*.yml)
    if [ ! -e "${rule_files[0]}" ]; then
        echo "Warning: No rule files found in $rules_dir"
        return 1
    fi
    
    local processed=0
    local failed=0
    
    for rule_file in "$rules_dir"/*.yml; do
        if [ -f "$rule_file" ]; then
            echo "Processing rules from file: $rule_file"
            if process_rule_file "$rule_file" "$db_name" "$port"; then
                ((processed++))
            else
                ((failed++))
            fi
        fi
    done
    
    echo "Rule processing complete:"
    echo "Successfully processed: $processed files"
    echo "Failed: $failed files"
    
    return 0
}