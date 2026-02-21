#!/bin/bash
set -e

LDAP_URI="${LDAP_URI:-ldap://localhost}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=example,dc=com}"

ldapsearch -x -H "$LDAP_URI" -b "$LDAP_BASE_DN" -s base "(objectClass=*)" dn > /dev/null 2>&1

exit $?
