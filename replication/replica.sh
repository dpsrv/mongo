#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo replica

conf=$( mongo-main --quiet --eval 'EJSON.stringify(rs.conf())' )
echo "$conf" | jq -r '.members[] | select(.host == "'$node:27017'").host' || mongo-admin --quiet --eval 'rs.add( { host: "'$node:27017'" } )'
