#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/dumper.sh"

# Print help message
print_help() {
    echo "Database Dump Tool"
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  dump     Create a dump of original database"
    echo "  import   Import a dump file into a database"
    echo "  anon     Create an anonymized dump"
    echo
    echo "Options for dump:"
    echo "  -h <host>     Database host"
    echo "  -p <port>     Database port"
    echo "  -u <user>     Database user"
    echo "  -w <pass>     Database password"
    echo "  -d <dbname>   Database name"
    echo "  -o <output>   Output file"
    echo
    echo "Options for import:"
    echo "  -h <host>     Target database host"
    echo "  -p <port>     Target database port"
    echo "  -w <pass>     Target database password"
    echo "  -d <dbname>   Target database name"
    echo "  -i <input>    Input dump file"
    echo
    echo "Options for anon:"
    echo "  -h <host>     Database host"
    echo "  -p <port>     Database port"
    echo "  -d <dbname>   Database name"
    echo "  -o <output>   Output file"
    echo
    echo "Examples:"
    echo "  $0 dump -h localhost -p 5432 -u myuser -w mypass -d mydb -o dump.sql"
    echo "  $0 import -h localhost -p 5432 -w mypass -d mydb -i dump.sql"
    echo "  $0 anon -h localhost -p 5432 -d mydb -o anon_dump.sql"
}

# Function to handle dump command
handle_dump() {
    local host port user pass dbname output
    
    while getopts "h:p:u:w:d:o:" opt; do
        case $opt in
            h) host="$OPTARG" ;;
            p) port="$OPTARG" ;;
            u) user="$OPTARG" ;;
            w) pass="$OPTARG" ;;
            d) dbname="$OPTARG" ;;
            o) output="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" ; exit 1 ;;
        esac
    done

    if [ -z "$host" ] || [ -z "$port" ] || [ -z "$user" ] || [ -z "$pass" ] || [ -z "$dbname" ] || [ -z "$output" ]; then
        echo "Error: Missing required parameters"
        print_help
        exit 1
    fi

    dump_original_db "$host" "$port" "$user" "$pass" "$dbname" "$output"
}

# Function to handle import command
handle_import() {
    local host port pass dbname input
    
    while getopts "h:p:w:d:i:" opt; do
        case $opt in
            h) host="$OPTARG" ;;
            p) port="$OPTARG" ;;
            w) pass="$OPTARG" ;;
            d) dbname="$OPTARG" ;;
            i) input="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" ; exit 1 ;;
        esac
    done

    if [ -z "$host" ] || [ -z "$port" ] || [ -z "$pass" ] || [ -z "$dbname" ] || [ -z "$input" ]; then
        echo "Error: Missing required parameters"
        print_help
        exit 1
    fi

    import_dump "$host" "$port" "$pass" "$dbname" "$input"
}

# Function to handle anon command
handle_anon() {
    local host port dbname output
    
    while getopts "h:p:d:o:" opt; do
        case $opt in
            h) host="$OPTARG" ;;
            p) port="$OPTARG" ;;
            d) dbname="$OPTARG" ;;
            o) output="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" ; exit 1 ;;
        esac
    done

    if [ -z "$host" ] || [ -z "$port" ] || [ -z "$dbname" ] || [ -z "$output" ]; then
        echo "Error: Missing required parameters"
        print_help
        exit 1
    fi

    create_anonymized_dump "$host" "$port" "$dbname" "$output"
}

# Main script logic
case "$1" in
    dump)
        shift
        handle_dump "$@"
        ;;
    import)
        shift
        handle_import "$@"
        ;;
    anon)
        shift
        handle_anon "$@"
        ;;
    help|-h|--help)
        print_help
        exit 0
        ;;
    *)
        echo "Unknown command: $1"
        print_help
        exit 1
        ;;
esac