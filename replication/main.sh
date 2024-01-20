#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

conf=$( mongo-local --quiet --eval 'EJSON.stringify(rs.conf())' || true )
host=$( echo "$conf" | jq -r '.members[] | select(.host == "'$node:27017'").host' )

if [ -z $host ]; then
	mongo-local --quiet --eval 'rs.initiate({
		_id: "dpsrv", members: [ { _id: 0, host: "'"$node:27017"'", priority: 1 } ]
	})' 
	exit 1
fi

conf=$( echo "$conf" | jq '(.members[] | select(.host != "'"$node:27017"'")).priority |= 0' )
conf=$( echo "$conf" | jq '(.members[] | select(.host == "'"$node:27017"'")).priority |= 1' )
conf=$( echo "$conf" | jq -c . | sed 's/{"$oid":"\([^"]*\)"}/ObjectId("\1")/g' )

mongo-local --quiet --eval 'rs.reconfig('"$conf"')'

