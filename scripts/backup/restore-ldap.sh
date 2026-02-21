#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ldap}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] BACKUP_FILE

Restore LDAP from backup.

Options:
    -d, --decrypt        GPG passphrase for encrypted backups
    -f, --force          Force restore without confirmation
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} ldap-backup-20240101_120000.tar.gz
    ${SCRIPT_NAME} --decrypt "passphrase" ldap-backup-20240101_120000.tar.gz.gpg
EOF
}

restore_ldap() {
    local backup_file="$1"
    local force="$2"
    local passphrase="$3"
    
    if [[ ! -f "$backup_file" ]]; then
        echo "Error: Backup file $backup_file not found" >&2
        exit 1
    fi
    
    if [[ "$backup_file" == *.gpg ]]; then
        if [[ -z "$passphrase" ]]; then
            read -rsp "Enter GPG passphrase: " passphrase
            echo
        fi
        echo "Decrypting backup..."
        echo "$passphrase" | gpg --batch --yes --passphrase-fd 0 --decrypt "$backup_file" > "${backup_file%.gpg}"
        backup_file="${backup_file%.gpg}"
    fi
    
    if [[ "$backup_file" == *.tar.gz ]]; then
        echo "Extracting backup archive..."
        tar -xzf "$backup_file" -C /tmp
        backup_file="/tmp"
    fi
    
    if [[ -f "$backup_file" && "$backup_file" == *.ldif ]]; then
        local db_file="$backup_file"
        local config_file="${backup_file/data/config}"
    elif [[ -d "$backup_file" ]]; then
        local db_file=$(find "$backup_file" -name "ldap-data-*.ldif" | head -1)
        local config_file=$(find "$backup_file" -name "ldap-config-*.ldif" | head -1)
    fi
    
    if [[ -z "$db_file" || ! -f "$db_file" ]]; then
        echo "Error: Database backup file not found" >&2
        exit 1
    fi
    
    if [[ -z "$config_file" || ! -f "$config_file" ]]; then
        echo "Error: Configuration backup file not found" >&2
        exit 1
    fi
    
    echo "Backup files:"
    echo "  Database: $db_file"
    echo "  Configuration: $config_file"
    
    if [[ "$force" != "true" ]]; then
        echo ""
        echo "WARNING: This will overwrite the current LDAP database and configuration!"
        read -rp "Are you sure you want to continue? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            exit 0
        fi
    fi
    
    echo "Stopping LDAP service..."
    systemctl stop slapd 2>/dev/null || service slapd stop 2>/dev/null || true
    
    echo "Removing existing database..."
    rm -rf /var/lib/ldap/*
    rm -rf /etc/ldap/slapd.d/*
    
    echo "Restoring configuration..."
    slapadd -n 0 -l "$config_file" -F /etc/ldap/slapd.d
    
    echo "Restoring database..."
    slapadd -n 1 -l "$db_file"
    
    echo "Setting permissions..."
    chown -R openldap:openldap /var/lib/ldap
    chown -R openldap:openldap /etc/ldap/slapd.d
    
    echo "Starting LDAP service..."
    systemctl start slapd 2>/dev/null || service slapd start 2>/dev/null || true
    
    echo "Verifying restoration..."
    sleep 5
    if ldapsearch -x -H ldap://localhost -b "$LDAP_BASE_DN" "(objectClass=*)" dn >/dev/null 2>&1; then
        echo "LDAP restored successfully!"
    else
        echo "Warning: LDAP verification failed. Check the logs." >&2
    fi
    
    rm -f /tmp/ldap-*.ldif 2>/dev/null || true
}

main() {
    local backup_file=""
    local force="false"
    local passphrase=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--decrypt)
                passphrase="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
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
                backup_file="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$backup_file" ]]; then
        echo "Error: Backup file is required" >&2
        usage
        exit 1
    fi
    
    restore_ldap "$backup_file" "$force" "$passphrase"
}

main "$@"
