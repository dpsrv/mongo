#!/bin/bash -ex

/usr/local/bin/update-certs.sh 

exec mongod --config /etc/mongo/mongod.conf
