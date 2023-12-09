#!/bin/bash -ex

/opt/update-certs.sh 

#/opt/replication/replication.sh &

exec /usr/local/bin/docker-entrypoint.sh mongod --config /etc/mongo/mongod.conf
