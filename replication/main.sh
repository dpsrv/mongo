#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo main

conf=$( mongo-local --quiet --eval 'EJSON.stringify(rs.conf())' || true )
if [ -z $conf ]; then
	mongo-local --quiet --eval 'rs.initiate({
		_id: "dpsrv", members: [ { _id: 0, host: "'$DPSRV_REGION-$DPSRV_NODE.$DPSRV_DOMAIN:27017'" } ]
	})' 
fi

echo $conf
