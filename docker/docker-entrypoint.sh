#!/bin/bash -ex

if [ -n "$*" ]; then
	exec "$@"
fi

cp -R /etc/mongo.init /etc/mongo
chown -R mongodb:mongodb /etc/mongo/*
chmod -R u=r,og= /etc/mongo/*

/opt/update-certs.sh 

/opt/replication/replication.sh &

. /opt/replication/setenv.sh
exec /usr/local/bin/docker-entrypoint.sh mongod --config /etc/mongo/mongod.conf --replSet $DPSRV_MONGO_CLUSTER
