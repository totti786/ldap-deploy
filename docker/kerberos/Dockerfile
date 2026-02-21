FROM debian:bookworm-slim

LABEL maintainer="Tarek Deshli <totti786@gmail.com>"
LABEL description="MIT Kerberos KDC with LDAP backend"

ENV DEBIAN_FRONTEND=noninteractive
ENV KRB5_REALM=EXAMPLE.COM
ENV KRB5_KDC=kdc.example.com
ENV KRB5_ADMIN_PASSWORD=admin

RUN apt-get update && apt-get install -y \
    krb5-kdc \
    krb5-admin-server \
    krb5-user \
    libkadm5clnt-mit12 \
    libkadm5srv-mit12 \
    libkrb5-3 \
    libldap-2.5-0 \
    ldap-utils \
    openssl \
    ca-certificates \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

COPY config/krb5.conf /etc/krb5.conf
COPY config/kdc.conf /etc/krb5kdc/kdc.conf
COPY config/kadm5.acl /etc/krb5kdc/kadm5.acl
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh
COPY scripts/init-kdc.sh /init-kdc.sh

RUN mkdir -p /var/log/krb5 /etc/krb5kdc \
    && chmod +x /entrypoint.sh /healthcheck.sh /init-kdc.sh

EXPOSE 88/udp 88/tcp 464/udp 464/tcp 749/tcp

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh || exit 1

ENTRYPOINT ["/entrypoint.sh"]
