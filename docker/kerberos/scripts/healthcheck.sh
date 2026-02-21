#!/bin/bash

KRB5_REALM="${KRB5_REALM:-EXAMPLE.COM}"

if kadmin.local -q "list_principals" 2>/dev/null | grep -q "admin/admin@${KRB5_REALM}"; then
    exit 0
fi

exit 1
