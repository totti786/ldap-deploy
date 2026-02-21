#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${LDAP_BASE_DN}}"
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] USERNAME

Create a new LDAP user account.

Options:
    -f, --firstname      User's first name (required)
    -l, --lastname       User's last name (required)
    -e, --email          User's email address (required)
    -g, --group          Primary group (default: users)
    -s, --shell          Login shell (default: /bin/bash)
    -u, --uid            Custom UID number (auto-generated if not provided)
    -G, --gid            Custom GID number (default: 10000)
    -p, --password       User password (prompted if not provided)
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} -f John -l Doe -e john.doe@example.com jdoe
    ${SCRIPT_NAME} --firstname John --lastname Doe --email john@example.com jdoe
EOF
}

generate_uid() {
    local base_uid=10000
    local max_uid=60000
    
    local highest_uid
    highest_uid=$(ldapsearch -x -H "$LDAP_URI" -b "$LDAP_BASE_DN" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" "(objectClass=posixAccount)" uidNumber 2>/dev/null | grep -E '^uidNumber:' | awk '{print $2}' | sort -n | tail -1)
    
    if [[ -n "$highest_uid" && "$highest_uid" -gt "$base_uid" ]]; then
        echo $((highest_uid + 1))
    else
        echo $((base_uid + 1))
    fi
}

create_user() {
    local username="$1"
    local firstname="$2"
    local lastname="$3"
    local email="$4"
    local group="${5:-users}"
    local shell="${6:-/bin/bash}"
    local uid_number="$7"
    local gid_number="${8:-10000}"
    local password="$9"
    
    if [[ -z "$uid_number" ]]; then
        uid_number=$(generate_uid)
    fi
    
    local home_dir="/home/$username"
    local full_name="$firstname $lastname"
    
    local password_hash
    password_hash=$(slappasswd -s "$password")
    
    local ldif_content
    ldif_content=$(cat << EOF
dn: uid=$username,ou=People,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
objectClass: top
uid: $username
cn: $full_name
sn: $lastname
givenName: $firstname
displayName: $full_name
mail: $email
uidNumber: $uid_number
gidNumber: $gid_number
userPassword: $password_hash
loginShell: $shell
homeDirectory: $home_dir
shadowLastChange: 0
shadowMax: 99999
shadowWarning: 7
shadowInactive: -1
shadowExpire: -1
shadowFlag: 0
EOF
)
    
    echo "$ldif_content" | ldapadd -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD"
    
    if [[ $? -eq 0 ]]; then
        echo "User $username created successfully with UID $uid_number"
        
        ldapmodify -x -H "$LDAP_URI" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" << EOF
dn: cn=$group,ou=Groups,$LDAP_BASE_DN
changetype: modify
add: member
member: uid=$username,ou=People,$LDAP_BASE_DN
EOF
        
        echo "User $username added to group $group"
    else
        echo "Failed to create user $username" >&2
        return 1
    fi
}

main() {
    local firstname=""
    local lastname=""
    local email=""
    local group="users"
    local shell="/bin/bash"
    local uid_number=""
    local gid_number="10000"
    local password=""
    local username=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--firstname)
                firstname="$2"
                shift 2
                ;;
            -l|--lastname)
                lastname="$2"
                shift 2
                ;;
            -e|--email)
                email="$2"
                shift 2
                ;;
            -g|--group)
                group="$2"
                shift 2
                ;;
            -s|--shell)
                shell="$2"
                shift 2
                ;;
            -u|--uid)
                uid_number="$2"
                shift 2
                ;;
            -G|--gid)
                gid_number="$2"
                shift 2
                ;;
            -p|--password)
                password="$2"
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
    
    if [[ -z "$firstname" ]]; then
        read -rp "Enter first name: " firstname
    fi
    
    if [[ -z "$lastname" ]]; then
        read -rp "Enter last name: " lastname
    fi
    
    if [[ -z "$email" ]]; then
        read -rp "Enter email address: " email
    fi
    
    if [[ -z "$password" ]]; then
        read -rsp "Enter password: " password
        echo
        read -rsp "Confirm password: " password_confirm
        echo
        
        if [[ "$password" != "$password_confirm" ]]; then
            echo "Error: Passwords do not match" >&2
            exit 1
        fi
    fi
    
    if [[ -z "$LDAP_ADMIN_PASSWORD" ]]; then
        read -rsp "Enter LDAP admin password: " LDAP_ADMIN_PASSWORD
        echo
        export LDAP_ADMIN_PASSWORD
    fi
    
    create_user "$username" "$firstname" "$lastname" "$email" "$group" "$shell" "$uid_number" "$gid_number" "$password"
}

main "$@"
