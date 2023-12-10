#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

conf=$( mongo-local --quiet --eval 'EJSON.stringify(rs.conf())' || true )
echo "rs.conf: $conf"

host=$( echo "$conf" | jq -r '.members[] | select(.host == "'$node:27017'").host' )

if [ -z $host ]; then
	mongo-local --quiet --eval 'rs.initiate({
		_id: "dpsrv", members: [ { _id: 0, host: "'$node:27017'" } ]
	})' 
	exit 1
fi

echo "main node $host"
