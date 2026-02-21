FROM osixia/openldap:1.5.0

LABEL maintainer="Tarek Deshli <totti786@gmail.com>"
LABEL description="Custom OpenLDAP with additional schemas and tools"

RUN apt-get update && apt-get install -y \
    ldap-utils \
    openssl \
    ca-certificates \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh || exit 1

EXPOSE 389 636

ENTRYPOINT ["/container/tool/run", "--copy-service"]
CMD ["slapd", "-d", "32768", "-h", "ldap://$HOSTNAME ldaps://$HOSTNAME ldapi:///", "-F", "/etc/ldap/slapd.d"]
