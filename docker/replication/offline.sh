#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

export DPSRV_MONGO_SELF="$node:27017"

primary=$(find_primary)
[ -n "$primary" ]

# A primary cannot remove itself, step down first and remove on the next pass
if [ "$primary" = "$DPSRV_MONGO_SELF" ]; then
	mongo-local --quiet --eval 'rs.stepDown()' || true
	exit 0
fi

mongo ${primary%:*} --quiet --eval '
const self = process.env.DPSRV_MONGO_SELF;
if (rs.conf().members.some(m => m.host === self)) {
	rs.remove(self);
}
'
