#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

conf=$( mongo-main --quiet --eval 'EJSON.stringify(rs.conf())' || true )
host=$( echo "$conf" | jq -r '.members[] | select(.host == "'"$node:27017"'").host' )

if [ -z $host ]; then
	mongo-main --quiet --eval 'rs.add( { host: "'"$node:27017"'", priority: 0 } )'
fi

