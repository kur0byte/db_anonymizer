#!/bin/bash

# Function to parse YAML files
parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
         -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$|\1$prefix\2=\"\3\"|p" \
         -e "s|^\($s\)\($w\)$s:$s\(.*\)$|\1$prefix\2=\"\3\"|p" $1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check port availability
check_port_available() {
    ! lsof -Pi :"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

# Function to find an available port
find_available_port() {
    local port=${1:-15432}
    while ! check_port_available $port; do
        port=$((port + 1))
    done
    echo $port
}

# Function to validate database configuration
validate_db_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file not found: $config_file"
        return 1
    fi
    
    local required_fields=("host" "port" "database" "user" "password")
    local missing_fields=()
    
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" "$config_file"; then
            missing_fields+=("$field")
        fi
    done
    
    if [ ${#missing_fields[@]} -ne 0 ]; then
        echo "Error: Missing required fields in configuration:"
        printf '%s\n' "${missing_fields[@]}"
        return 1
    fi
    
    return 0
}

# Function to validate rules configuration
validate_rules_config() {
    local rule_file=$1
    
    if [ ! -f "$rule_file" ]; then
        echo "Error: Rule file not found: $rule_file"
        return 1
    fi
    
    local required_sections=("table" "columns" "mask_functions")
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "^$section:" "$rule_file"; then
            missing_sections+=("$section")
        fi
    done
    
    if [ ${#missing_sections[@]} -ne 0 ]; then
        echo "Error: Missing required sections in rule file:"
        printf '%s\n' "${missing_sections[@]}"
        return 1
    fi
    
    return 0
}

# Function to log messages with timestamp
log_message() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Function to get formatted datetime string
get_datetime_string() {
    date "+%Y%m%d_%H%M%S"
}

# Function to create dumps directory structure
create_dumps_directory() {
    local base_dir=$1
    local db_name=$2
    local datetime=$(get_datetime_string)
    
    # Create the base dumps directory if it doesn't exist
    if [ ! -d "$base_dir" ]; then
        mkdir -p "$base_dir"
    fi
    
    # Create datetime directory
    local dump_dir="$base_dir/$datetime"
    mkdir -p "$dump_dir"
    
    # Return the full path for the dump file
    echo "$dump_dir/${db_name}.dump.sql"
}

# Function to cleanup old dumps (optional, keeps last N dumps)
cleanup_old_dumps() {
    local base_dir=$1
    local keep_last=$2  # Number of recent dumps to keep
    
    # List directories by date (oldest first) and remove excess
    if [ -d "$base_dir" ]; then
        local dir_count=$(ls -1 "$base_dir" | wc -l)
        if [ "$dir_count" -gt "$keep_last" ]; then
            cd "$base_dir" && ls -1t | tail -n +$((keep_last + 1)) | xargs rm -rf
        fi
    fi
}