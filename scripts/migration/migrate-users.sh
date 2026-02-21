#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SOURCE_HOST="${SOURCE_HOST:-}"
SOURCE_USER="${SOURCE_USER:-root}"
LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${LDAP_BASE_DN}}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] SOURCE_HOST

Migrate users from source LDAP server.

Options:
    -u, --user           SSH user for source host (default: root)
    -b, --base-dn        Base DN to migrate from
    -o, --output         Output LDIF file (default: migration.ldif)
    -i, --import         Import directly to local LDAP
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} ldap-old.example.com
    ${SCRIPT_NAME} -u admin -o users.ldif ldap-old.example.com
    ${SCRIPT_NAME} --import ldap-old.example.com
EOF
}

migrate_users() {
    local source_host="$1"
    local source_user="$2"
    local base_dn="$3"
    local output_file="$4"
    local do_import="$5"
    
    echo "Starting migration from $source_host..."
    
    echo "Extracting users from source LDAP..."
    ssh "${source_user}@${source_host}" "ldapsearch -x -b '${base_dn}' '(objectClass=inetOrgPerson)' -LLL" > "${output_file}.tmp"
    
    echo "Extracting groups from source LDAP..."
    ssh "${source_user}@${source_host}" "ldapsearch -x -b '${base_dn}' '(objectClass=posixGroup)' -LLL" >> "${output_file}.tmp"
    
    echo "Processing migration data..."
    grep -v "^dn:" "${output_file}.tmp" | grep -v "^$" > "$output_file" || true
    
    rm -f "${output_file}.tmp"
    
    local user_count
    user_count=$(grep -c "^uid:" "$output_file" || echo "0")
    local group_count
    group_count=$(grep -c "^cn:" "$output_file" || echo "0")
    
    echo "Migration data extracted:"
    echo "  Users: $user_count"
    echo "  Groups: $group_count"
    echo "  Output: $output_file"
    
    if [[ "$do_import" == "true" ]]; then
        echo "Importing to local LDAP..."
        ldapadd -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$output_file"
        
        if [[ $? -eq 0 ]]; then
            echo "Migration completed successfully!"
        else
            echo "Warning: Some entries may have failed to import" >&2
        fi
    fi
}

main() {
    local source_host=""
    local source_user="$SOURCE_USER"
    local base_dn="$LDAP_BASE_DN"
    local output_file="migration-$(date +%Y%m%d).ldif"
    local do_import="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user)
                source_user="$2"
                shift 2
                ;;
            -b|--base-dn)
                base_dn="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -i|--import)
                do_import="true"
                shift
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
            *)
                source_host="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$source_host" ]]; then
        echo "Error: Source host is required" >&2
        usage
        exit 1
    fi
    
    if [[ -z "${LDAP_ADMIN_PASSWORD:-}" ]]; then
        read -rsp "Enter LDAP admin password: " LDAP_ADMIN_PASSWORD
        echo
        export LDAP_ADMIN_PASSWORD
    fi
    
    migrate_users "$source_host" "$source_user" "$base_dn" "$output_file" "$do_import"
}

main "$@"
