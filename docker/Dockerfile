ARG MONGO_VERSION=9.0.2
FROM mongo:${MONGO_VERSION}

RUN apt update \
	&& apt install -y dnsutils vim gettext \
	&& rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

COPY docker-entrypoint.sh update-certs.sh /opt
COPY replication /opt/replication

ENTRYPOINT [ "/opt/docker-entrypoint.sh" ]
