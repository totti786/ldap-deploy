#!/bin/bash
set -e

KRB5_REALM="${KRB5_REALM:-EXAMPLE.COM}"
KRB5_ADMIN_PASSWORD="${KRB5_ADMIN_PASSWORD:-admin}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"

echo "Creating Kerberos database..."
echo -n "${KRB5_ADMIN_PASSWORD}" | kdb5_ldap_util -D cn=admin,${LDAP_BASE_DN} create -subtrees ${LDAP_BASE_DN} -r ${KRB5_REALM} -sf /etc/krb5kdc/.k5.${KRB5_REALM} -w ${KRB5_ADMIN_PASSWORD} -H ldap://openldap -s -P -

echo "Creating stash file..."
echo -n "${KRB5_ADMIN_PASSWORD}" | kdb5_ldap_util -D cn=admin,${LDAP_BASE_DN} stash -r ${KRB5_REALM} -f /etc/krb5kdc/.k5.${KRB5_REALM} -w ${KRB5_ADMIN_PASSWORD} -H ldap://openldap

echo "Creating service keytab..."
kadmin.local -q "addprinc -pw ${KRB5_ADMIN_PASSWORD} admin/admin@${KRB5_REALM}"
kadmin.local -q "addprinc -randkey host/$(hostname)@${KRB5_REALM}"
kadmin.local -q "addprinc -randkey ldap/$(hostname)@${KRB5_REALM}"
kadmin.local -q "addprinc -randkey HTTP/$(hostname)@${KRB5_REALM}"

kadmin.local -q "ktadd -k /etc/krb5.keytabs/ldap.keytab ldap/$(hostname)@${KRB5_REALM}"
kadmin.local -q "ktadd -k /etc/krb5.keytabs/http.keytab HTTP/$(hostname)@${KRB5_REALM}"
kadmin.local -q "ktadd -k /etc/krb5kdc/kadm5.keytab kadmin/admin@${KRB5_REALM} kadmin/changepw@${KRB5_REALM}"

chmod 644 /etc/krb5.keytabs/*.keytab 2>/dev/null || true
chmod 600 /etc/krb5kdc/kadm5.keytab

echo "Kerberos KDC initialization complete."
