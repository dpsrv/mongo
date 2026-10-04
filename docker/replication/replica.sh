#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

export DPSRV_MONGO_SELF="$node:27017"

primary=$(find_primary)
[ -n "$primary" ]

mongo ${primary%:*} --quiet --eval '
const self = process.env.DPSRV_MONGO_SELF;
if (!rs.conf().members.some(m => m.host === self)) {
	rs.add({ host: self, priority: 0 });
}
'
