#!/bin/bash

SAMBA_REALM="${SAMBA_REALM:-example.com}"

if smbclient -L localhost -U% 2>/dev/null | grep -q "Domain"; then
    exit 0
fi

exit 1
