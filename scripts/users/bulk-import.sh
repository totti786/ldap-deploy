#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Bulk import users from CSV file.

Options:
    -f, --file           CSV file to import (required)
    -d, --delimiter      CSV delimiter (default: ,)
    -h, --help           Show this help message

CSV Format:
    username,firstname,lastname,email,group,shell,uid,gid,password

Examples:
    ${SCRIPT_NAME} -f users.csv
    ${SCRIPT_NAME} --file users.csv --delimiter ";"
EOF
}

import_users() {
    local csv_file="$1"
    local delimiter="$2"
    
    if [[ ! -f "$csv_file" ]]; then
        echo "Error: File $csv_file not found" >&2
        exit 1
    fi
    
    local line_num=0
    local success=0
    local failed=0
    
    while IFS="$delimiter" read -r username firstname lastname email group shell uid gid password || [[ -n "$username" ]]; do
        line_num=$((line_num + 1))
        
        if [[ $line_num -eq 1 ]]; then
            continue
        fi
        
        if [[ -z "$username" ]]; then
            continue
        fi
        
        group="${group:-users}"
        shell="${shell:-/bin/bash}"
        gid="${gid:-10000}"
        
        echo "Processing user: $username"
        
        if /usr/local/bin/create-user.sh -f "$firstname" -l "$lastname" -e "$email" -g "$group" -s "$shell" -u "$uid" -G "$gid" -p "$password" "$username" 2>/dev/null; then
            success=$((success + 1))
            echo "  [OK] User $username created"
        else
            failed=$((failed + 1))
            echo "  [FAIL] Failed to create user $username"
        fi
    done < "$csv_file"
    
    echo ""
    echo "Import completed:"
    echo "  Successful: $success"
    echo "  Failed: $failed"
    echo "  Total: $((success + failed))"
}

main() {
    local csv_file=""
    local delimiter=","
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                csv_file="$2"
                shift 2
                ;;
            -d|--delimiter)
                delimiter="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$csv_file" ]]; then
        echo "Error: CSV file is required" >&2
        usage
        exit 1
    fi
    
    if [[ -z "${LDAP_ADMIN_PASSWORD:-}" ]]; then
        read -rsp "Enter LDAP admin password: " LDAP_ADMIN_PASSWORD
        echo
        export LDAP_ADMIN_PASSWORD
    fi
    
    import_users "$csv_file" "$delimiter"
}

main "$@"
