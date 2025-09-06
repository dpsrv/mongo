#!/bin/bash -ex

if [ -n "$*" ]; then
	exec "$@"
fi

cp -R /etc/mongo.init /etc/mongo

. /opt/replication/setenv.sh
cat /etc/mongo.init/mongod.conf | envsubst > /etc/mongo/mongod.conf

chown -R mongodb:mongodb /etc/mongo/*
chmod -R u=r,og= /etc/mongo/*

/opt/update-certs.sh 

/opt/replication/replication.sh &

exec /usr/local/bin/docker-entrypoint.sh mongod --config /etc/mongo/mongod.conf
