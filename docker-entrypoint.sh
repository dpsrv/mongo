#!/bin/bash -ex

if [ -n "$*" ]; then
	exec "$@"
fi

/opt/update-certs.sh 

/opt/replication/replication.sh &

chown -R mongodb:mongodb /etc/mongo/*
chmod og-rwx /etc/mongo/dpsrv.key

exec /usr/local/bin/docker-entrypoint.sh mongod --config /etc/mongo/mongod.conf
