#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${LDAP_BASE_DN}}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] USERNAME

Modify an LDAP user account.

Options:
    -e, --email          Change email address
    -s, --shell          Change login shell
    -p, --password       Change password
    -l, --lock           Lock account
    -u, --unlock         Unlock account
    -g, --add-group      Add user to group
    -r, --remove-group   Remove user from group
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} --email new.email@example.com jdoe
    ${SCRIPT_NAME} --add-group developers jdoe
    ${SCRIPT_NAME} --lock jdoe
EOF
}

change_password() {
    local username="$1"
    local password="$2"
    
    local password_hash
    password_hash=$(slappasswd -s "$password")
    
    ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: uid=$username,ou=People,$LDAP_BASE_DN
changetype: modify
replace: userPassword
userPassword: $password_hash
EOF
    
    echo "Password changed for user $username"
}

lock_account() {
    local username="$1"
    
    ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: uid=$username,ou=People,$LDAP_BASE_DN
changetype: modify
replace: pwdAccountLockedTime
pwdAccountLockedTime: 000001010000Z
EOF
    
    echo "Account $username locked"
}

unlock_account() {
    local username="$1"
    
    ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: uid=$username,ou=People,$LDAP_BASE_DN
changetype: modify
delete: pwdAccountLockedTime
EOF
    
    echo "Account $username unlocked"
}

add_to_group() {
    local username="$1"
    local group="$2"
    
    ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: cn=$group,ou=Groups,$LDAP_BASE_DN
changetype: modify
add: member
member: uid=$username,ou=People,$LDAP_BASE_DN
EOF
    
    echo "User $username added to group $group"
}

remove_from_group() {
    local username="$1"
    local group="$2"
    
    ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: cn=$group,ou=Groups,$LDAP_BASE_DN
changetype: modify
delete: member
member: uid=$username,ou=People,$LDAP_BASE_DN
EOF
    
    echo "User $username removed from group $group"
}

main() {
    local email=""
    local shell=""
    local password=""
    local lock="false"
    local unlock="false"
    local add_group=""
    local remove_group=""
    local username=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--email)
                email="$2"
                shift 2
                ;;
            -s|--shell)
                shell="$2"
                shift 2
                ;;
            -p|--password)
                password="$2"
                shift 2
                ;;
            -l|--lock)
                lock="true"
                shift
                ;;
            -u|--unlock)
                unlock="true"
                shift
                ;;
            -g|--add-group)
                add_group="$2"
                shift 2
                ;;
            -r|--remove-group)
                remove_group="$2"
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
    
    if [[ -n "$email" ]]; then
        ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: uid=$username,ou=People,$LDAP_BASE_DN
changetype: modify
replace: mail
mail: $email
EOF
        echo "Email changed for user $username"
    fi
    
    if [[ -n "$shell" ]]; then
        ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: uid=$username,ou=People,$LDAP_BASE_DN
changetype: modify
replace: loginShell
loginShell: $shell
EOF
        echo "Shell changed for user $username"
    fi
    
    if [[ -n "$password" ]]; then
        change_password "$username" "$password"
    fi
    
    if [[ "$lock" == "true" ]]; then
        lock_account "$username"
    fi
    
    if [[ "$unlock" == "true" ]]; then
        unlock_account "$username"
    fi
    
    if [[ -n "$add_group" ]]; then
        add_to_group "$username" "$add_group"
    fi
    
    if [[ -n "$remove_group" ]]; then
        remove_from_group "$username" "$remove_group"
    fi
}

main "$@"
