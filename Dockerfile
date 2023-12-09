FROM mongo:latest

RUN apt update \
	&& apt install -y dnsutils \
	&& rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

COPY replication /opt/replication
