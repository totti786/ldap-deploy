FROM debian:bookworm-slim

LABEL maintainer="Tarek Deshli <totti786@gmail.com>"
LABEL description="Samba Active Directory with LDAP backend"

ENV DEBIAN_FRONTEND=noninteractive
ENV SAMBA_DOMAIN=EXAMPLE
ENV SAMBA_REALM=example.com
ENV LDAP_URL=ldap://openldap
ENV LDAP_BASE_DN=dc=example,dc=com

RUN apt-get update && apt-get install -y \
    samba \
    samba-dsdb-modules \
    samba-vfs-modules \
    winbind \
    libnss-winbind \
    libpam-winbind \
    krb5-user \
    krb5-config \
    ldap-utils \
    smbclient \
    cifs-utils \
    supervisor \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY config/smb.conf /etc/samba/smb.conf
COPY config/krb5.conf /etc/krb5.conf
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh

RUN mkdir -p /var/log/samba /var/lib/samba /run/samba \
    && chmod +x /entrypoint.sh /healthcheck.sh

EXPOSE 139 445

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["smbd", "-F", "--no-process-group", "-d", "1"]
