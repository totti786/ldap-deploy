#!/bin/bash
set -e

SAMBA_DOMAIN="${SAMBA_DOMAIN:-EXAMPLE}"
SAMBA_REALM="${SAMBA_REALM:-example.com}"
LDAP_URL="${LDAP_URL:-ldap://openldap}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${LDAP_BASE_DN}}"
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-admin}"

mkdir -p /var/log/samba /var/lib/samba/netlogon /var/lib/samba/profiles /var/lib/samba/shared /var/lib/samba/backups /run/samba

if [ ! -f /var/lib/samba/.initialized ]; then
    echo "Initializing Samba configuration..."
    
    envsubst < /etc/samba/smb.conf > /etc/samba/smb.conf.tmp
    mv /etc/samba/smb.conf.tmp /etc/samba/smb.conf
    
    echo -n "${LDAP_ADMIN_PASSWORD}" | smbpasswd -s -a administrator || true
    
    touch /var/lib/samba/.initialized
    echo "Samba initialization complete."
fi

echo "Starting Samba services..."
exec supervisord -c /etc/supervisor/supervisord.conf
