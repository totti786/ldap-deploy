#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] COMMAND

LDAP metrics exporter.

Commands:
    collect              Collect metrics from LDAP
    serve                Start HTTP metrics server
    help                 Show this help message

Options:
    -p, --port           Metrics server port (default: 8080)
    -i, --interval       Collection interval in seconds (default: 30)
    -h, --help           Show this help message

Examples:
    ${SCRIPT_NAME} collect
    ${SCRIPT_NAME} serve --port 8080
EOF
}

collect_metrics() {
    local ldap_uri="${LDAP_URI:-ldap://localhost}"
    local base_dn="${LDAP_BASE_DN:-dc=example,dc=com}"
    
    local user_count
    user_count=$(ldapsearch -x -H "$ldap_uri" -b "$base_dn" "(objectClass=inetOrgPerson)" dn 2>/dev/null | grep -c "^dn:" || echo "0")
    
    local group_count
    group_count=$(ldapsearch -x -H "$ldap_uri" -b "$base_dn" "(objectClass=posixGroup)" dn 2>/dev/null | grep -c "^dn:" || echo "0")
    
    local bind_success
    bind_success=$(ldapsearch -x -H "$ldap_uri" -b "$base_dn" -s base "(objectClass=*)" dn >/dev/null 2>&1 && echo "1" || echo "0")
    
    cat << EOF
# HELP ldap_up LDAP server is up
# TYPE ldap_up gauge
ldap_up $bind_success

# HELP ldap_entries_total Total number of LDAP entries
# TYPE ldap_entries_total gauge
ldap_entries_total{objectClass="inetOrgPerson"} $user_count
ldap_entries_total{objectClass="posixGroup"} $group_count

# HELP ldap_scrape_duration_seconds Duration of metrics collection
# TYPE ldap_scrape_duration_seconds gauge
ldap_scrape_duration_seconds $(date +%s.%N | head -c -1)
EOF
}

serve_metrics() {
    local port="${1:-8080}"
    local interval="${2:-30}"
    
    echo "Starting LDAP metrics server on port $port"
    echo "Collection interval: ${interval}s"
    
    while true; do
        collect_metrics > /tmp/metrics.tmp
        mv /tmp/metrics.tmp /tmp/metrics
        
        {
            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Content-Type: text/plain; version=0.0.4\r"
            echo -e "\r"
            cat /tmp/metrics
        } | nc -l -p "$port" -q 1 || true
        
        sleep "$interval"
    done
}

main() {
    local command=""
    local port="8080"
    local interval="30"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--port)
                port="$2"
                shift 2
                ;;
            -i|--interval)
                interval="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            collect|serve|help)
                command="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    case "$command" in
        collect)
            collect_metrics
            ;;
        serve)
            serve_metrics "$port" "$interval"
            ;;
        help|*)
            usage
            ;;
    esac
}

main "$@"
