FROM mongo:7.0.6

RUN apt update \
	&& apt install -y dnsutils vim \
	&& rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

COPY docker-entrypoint.sh update-certs.sh /opt
COPY replication /opt/replication

ENTRYPOINT [ "/opt/docker-entrypoint.sh" ]
