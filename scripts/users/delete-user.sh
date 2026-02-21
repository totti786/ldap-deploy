#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${LDAP_BASE_DN}}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] USERNAME

Delete an LDAP user account.

Options:
    -r, --remove-home    Remove user's home directory
    -y, --yes            Skip confirmation prompt
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} jdoe
    ${SCRIPT_NAME} --remove-home jdoe
EOF
}

delete_user() {
    local username="$1"
    local remove_home="$2"
    local skip_confirm="$3"
    
    local user_dn="uid=$username,ou=People,$LDAP_BASE_DN"
    
    if [[ "$skip_confirm" != "true" ]]; then
        read -rp "Are you sure you want to delete user '$username'? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            exit 0
        fi
    fi
    
    local groups
    groups=$(ldapsearch -x -H "$LDAP_URI" -b "$LDAP_BASE_DN" "(member=$user_dn)" dn 2>/dev/null | grep -E '^dn:' | sed 's/^dn: //')
    
    for group_dn in $groups; do
        echo "Removing user from group: $group_dn"
        ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: $group_dn
changetype: modify
delete: member
member: $user_dn
EOF
    done
    
    echo "Deleting user: $user_dn"
    ldapdelete -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" "$user_dn"
    
    if [[ $? -eq 0 ]]; then
        echo "User $username deleted successfully"
        
        if [[ "$remove_home" == "true" ]]; then
            local home_dir="/home/$username"
            if [[ -d "$home_dir" ]]; then
                rm -rf "$home_dir"
                echo "Home directory $home_dir removed"
            fi
        fi
    else
        echo "Failed to delete user $username" >&2
        return 1
    fi
}

main() {
    local remove_home="false"
    local skip_confirm="false"
    local username=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--remove-home)
                remove_home="true"
                shift
                ;;
            -y|--yes)
                skip_confirm="true"
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
                username="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$username" ]]; then
        echo "Error: Username is required" >&2
        usage
        exit 1
    fi
    
    if [[ -z "${LDAP_ADMIN_PASSWORD:-}" ]]; then
        read -rsp "Enter LDAP admin password: " LDAP_ADMIN_PASSWORD
        echo
        export LDAP_ADMIN_PASSWORD
    fi
    
    delete_user "$username" "$remove_home" "$skip_confirm"
}

main "$@"
