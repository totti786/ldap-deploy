#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${LDAP_BASE_DN}}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} GROUPNAME DESCRIPTION

Create a new LDAP group.

Options:
    -g, --gid            Custom GID number (auto-generated if not provided)
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} developers "Development Team"
    ${SCRIPT_NAME} --gid 5000 sysadmins "System Administrators"
EOF
}

generate_gid() {
    local base_gid=10000
    local max_gid=60000
    
    local highest_gid
    highest_gid=$(ldapsearch -x -H "$LDAP_URI" -b "$LDAP_BASE_DN" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" "(objectClass=posixGroup)" gidNumber 2>/dev/null | grep -E '^gidNumber:' | awk '{print $2}' | sort -n | tail -1)
    
    if [[ -n "$highest_gid" && "$highest_gid" -gt "$base_gid" ]]; then
        echo $((highest_gid + 1))
    else
        echo $((base_gid + 1))
    fi
}

create_group() {
    local groupname="$1"
    local description="$2"
    local gid_number="$3"
    
    if [[ -z "$gid_number" ]]; then
        gid_number=$(generate_gid)
    fi
    
    local ldif_content
    ldif_content=$(cat << EOF
dn: cn=$groupname,ou=Groups,$LDAP_BASE_DN
objectClass: groupOfNames
objectClass: posixGroup
objectClass: top
cn: $groupname
gidNumber: $gid_number
description: $description
member: cn=dummy,dc=placeholder,dc=com
EOF
)
    
    echo "$ldif_content" | ldapadd -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD"
    
    ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: cn=$groupname,ou=Groups,$LDAP_BASE_DN
changetype: modify
delete: member
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "Group $groupname created successfully with GID $gid_number"
    else
        echo "Failed to create group $groupname" >&2
        return 1
    fi
}

main() {
    local gid_number=""
    local groupname=""
    local description=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--gid)
                gid_number="$2"
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
            *)
                if [[ -z "$groupname" ]]; then
                    groupname="$1"
                elif [[ -z "$description" ]]; then
                    description="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$groupname" ]]; then
        echo "Error: Groupname is required" >&2
        usage
        exit 1
    fi
    
    if [[ -z "$description" ]]; then
        read -rp "Enter group description: " description
    fi
    
    if [[ -z "${LDAP_ADMIN_PASSWORD:-}" ]]; then
        read -rsp "Enter LDAP admin password: " LDAP_ADMIN_PASSWORD
        echo
        export LDAP_ADMIN_PASSWORD
    fi
    
    create_group "$groupname" "$description" "$gid_number"
}

main "$@"
