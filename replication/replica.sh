#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo replica

mongo-admin --quiet --eval 'rs.add( { host: "'$DPSRV_REGION-$DPSRV_NODE.$DPSRV_DOMAIN:27017'" } )'
