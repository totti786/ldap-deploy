#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ldap}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Backup LDAP database and configuration.

Options:
    -o, --output         Backup output directory (default: /var/backups/ldap)
    -r, --retention      Retention period in days (default: 30)
    -c, --compress       Compress backup files (default: true)
    -e, --encrypt        Encrypt backup with GPG (default: false)
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --output /backups/ldap --retention 60
    ${SCRIPT_NAME} --encrypt
EOF
}

backup_ldap() {
    local backup_dir="$1"
    local compress="$2"
    local encrypt="$3"
    
    mkdir -p "$backup_dir"
    
    echo "Starting LDAP backup at $(date)"
    
    local db_backup="$backup_dir/ldap-data-${TIMESTAMP}.ldif"
    local config_backup="$backup_dir/ldap-config-${TIMESTAMP}.ldif"
    
    echo "Backing up LDAP database..."
    if slapcat -n 1 -l "$db_backup" 2>/dev/null; then
        echo "  Database backup: $db_backup"
    else
        echo "  [ERROR] Failed to backup database" >&2
        return 1
    fi
    
    echo "Backing up LDAP configuration..."
    if slapcat -n 0 -l "$config_backup" 2>/dev/null; then
        echo "  Configuration backup: $config_backup"
    else
        echo "  [ERROR] Failed to backup configuration" >&2
        return 1
    fi
    
    local backup_files="$db_backup $config_backup"
    
    if [[ "$compress" == "true" ]]; then
        local archive="$backup_dir/ldap-backup-${TIMESTAMP}.tar.gz"
        echo "Compressing backup files..."
        tar -czf "$archive" -C "$backup_dir" "$(basename "$db_backup")" "$(basename "$config_backup")"
        rm -f "$db_backup" "$config_backup"
        backup_files="$archive"
        echo "  Archive: $archive"
    fi
    
    if [[ "$encrypt" == "true" ]]; then
        echo "Encrypting backup..."
        for file in $backup_files; do
            gpg --symmetric --cipher-algo AES256 --output "${file}.gpg" "$file"
            rm -f "$file"
            echo "  Encrypted: ${file}.gpg"
        done
        backup_files="${backup_files}.gpg"
    fi
    
    local metadata="$backup_dir/metadata-${TIMESTAMP}.json"
    cat > "$metadata" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "base_dn": "$LDAP_BASE_DN",
    "hostname": "$(hostname)",
    "version": "$(slapd -V 2>&1 | head -1)",
    "files": $(echo "$backup_files" | jq -R -s -c 'split(" ") | map(select(length > 0))')
}
EOF
    
    echo "Metadata: $metadata"
    echo "Backup completed successfully at $(date)"
    
    return 0
}

cleanup_old_backups() {
    local backup_dir="$1"
    local retention="$2"
    
    echo "Cleaning up backups older than $retention days..."
    
    find "$backup_dir" -name "ldap-*.ldif" -type f -mtime "+$retention" -delete
    find "$backup_dir" -name "ldap-backup-*.tar.gz" -type f -mtime "+$retention" -delete
    find "$backup_dir" -name "ldap-*.gpg" -type f -mtime "+$retention" -delete
    find "$backup_dir" -name "metadata-*.json" -type f -mtime "+$retention" -delete
    
    local count
    count=$(find "$backup_dir" -type f \( -name "ldap-*.ldif" -o -name "ldap-backup-*.tar.gz" -o -name "ldap-*.gpg" \) | wc -l)
    echo "Remaining backups: $count"
}

main() {
    local backup_dir="$BACKUP_DIR"
    local retention="$RETENTION_DAYS"
    local compress="true"
    local encrypt="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                backup_dir="$2"
                shift 2
                ;;
            -r|--retention)
                retention="$2"
                shift 2
                ;;
            -c|--compress)
                compress="true"
                shift
                ;;
            --no-compress)
                compress="false"
                shift
                ;;
            -e|--encrypt)
                encrypt="true"
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
        esac
    done
    
    backup_ldap "$backup_dir" "$compress" "$encrypt"
    cleanup_old_backups "$backup_dir" "$retention"
}

main "$@"
