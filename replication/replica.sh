#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo replica

conf=$( mongo-main --quiet --eval 'EJSON.stringify(rs.conf())' )
echo "$conf" | jq '.members[] | select(.host == "'$DPSRV_REGION-$DPSRV_NODE.$DPSRV_DOMAIN:27017'").host' || mongo-admin --quiet --eval 'rs.add( { host: "'$DPSRV_REGION-$DPSRV_NODE.$DPSRV_DOMAIN:27017'" } )'
