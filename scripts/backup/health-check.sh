#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Verify LDAP integrity and health.

Options:
    -v, --verbose        Verbose output
    -j, --json           Output in JSON format
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --verbose
    ${SCRIPT_NAME} --json
EOF
}

check_ldap() {
    local verbose="$1"
    local json_output="$2"
    
    local status="healthy"
    local errors=()
    local warnings=()
    
    if ! systemctl is-active --quiet slapd 2>/dev/null && ! pgrep -x slapd >/dev/null; then
        status="critical"
        errors+=("LDAP service is not running")
    fi
    
    local ldap_uri="${LDAP_URI:-ldap://localhost}"
    local base_dn="${LDAP_BASE_DN:-dc=example,dc=com}"
    
    if ! ldapsearch -x -H "$ldap_uri" -b "$base_dn" -s base "(objectClass=*)" dn >/dev/null 2>&1; then
        status="critical"
        errors+=("LDAP search query failed")
    fi
    
    local user_count
    user_count=$(ldapsearch -x -H "$ldap_uri" -b "$base_dn" "(objectClass=inetOrgPerson)" dn 2>/dev/null | grep -c "^dn:" || echo "0")
    
    local group_count
    group_count=$(ldapsearch -x -H "$ldap_uri" -b "$base_dn" "(objectClass=posixGroup)" dn 2>/dev/null | grep -c "^dn:" || echo "0")
    
    if [[ "$user_count" -lt 1 ]]; then
        warnings+=("No users found in LDAP")
    fi
    
    local db_size
    db_size=$(du -sh /var/lib/ldap 2>/dev/null | awk '{print $1}' || echo "unknown")
    
    local config_size
    config_size=$(du -sh /etc/ldap/slapd.d 2>/dev/null | awk '{print $1}' || echo "unknown")
    
    local uptime
    uptime=$(systemctl show slapd --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2 || echo "unknown")
    
    if [[ "$json_output" == "true" ]]; then
        cat << EOF
{
    "status": "$status",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "metrics": {
        "user_count": $user_count,
        "group_count": $group_count,
        "database_size": "$db_size",
        "config_size": "$config_size"
    },
    "errors": $(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .),
    "warnings": $(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
}
EOF
    else
        echo "LDAP Health Check - $(date)"
        echo "================================"
        echo "Status: $status"
        echo ""
        echo "Metrics:"
        echo "  Users: $user_count"
        echo "  Groups: $group_count"
        echo "  Database Size: $db_size"
        echo "  Config Size: $config_size"
        
        if [[ ${#errors[@]} -gt 0 ]]; then
            echo ""
            echo "Errors:"
            for error in "${errors[@]}"; do
                echo "  [ERROR] $error"
            done
        fi
        
        if [[ ${#warnings[@]} -gt 0 ]]; then
            echo ""
            echo "Warnings:"
            for warning in "${warnings[@]}"; do
                echo "  [WARN] $warning"
            done
        fi
        
        if [[ "$verbose" == "true" ]]; then
            echo ""
            echo "Detailed Information:"
            echo "  LDAP URI: $ldap_uri"
            echo "  Base DN: $base_dn"
            echo "  Service Uptime: $uptime"
        fi
    fi
    
    if [[ "$status" == "critical" ]]; then
        return 1
    fi
    
    return 0
}

main() {
    local verbose="false"
    local json_output="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -j|--json)
                json_output="true"
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
    
    check_ldap "$verbose" "$json_output"
}

main "$@"
