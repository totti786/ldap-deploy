FROM osixia/phpldapadmin:0.9.0

LABEL maintainer="Tarek Deshli <totti786@gmail.com>"
LABEL description="phpLDAPadmin with custom configuration"

RUN apt-get update && apt-get install -y \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY config/config.php /etc/phpldapadmin/config.php
COPY config/nginx-default-site /etc/nginx/sites-available/default

RUN chmod 644 /etc/phpldapadmin/config.php

EXPOSE 80 443

ENTRYPOINT ["/container/tool/run"]
CMD ["--copy-service"]
