#!/bin/bash
set -e

KRB5_REALM="${KRB5_REALM:-EXAMPLE.COM}"
KRB5_ADMIN_PASSWORD="${KRB5_ADMIN_PASSWORD:-admin}"
LDAP_URL="${LDAP_URL:-ldap://openldap}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"

mkdir -p /var/log/krb5 /etc/krb5kdc /etc/krb5.keytabs

envsubst < /etc/krb5.conf > /etc/krb5.conf.tmp
mv /etc/krb5.conf.tmp /etc/krb5.conf

envsubst < /etc/krb5kdc/kdc.conf > /etc/krb5kdc/kdc.conf.tmp
mv /etc/krb5kdc/kdc.conf.tmp /etc/krb5kdc/kdc.conf

envsubst < /etc/krb5kdc/kadm5.acl > /etc/krb5kdc/kadm5.acl.tmp
mv /etc/krb5kdc/kadm5.acl.tmp /etc/krb5kdc/kadm5.acl

if [ ! -f /etc/krb5kdc/.k5.${KRB5_REALM} ]; then
    echo "Initializing Kerberos KDC..."
    /init-kdc.sh
fi

echo "Starting Kerberos KDC services..."
exec supervisord -c /etc/supervisor/supervisord.conf
