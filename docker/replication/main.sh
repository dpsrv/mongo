#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

export DPSRV_MONGO_SELF="$node:27017"

# Initiate a new replica set if this node has never been part of one
mongo-local --quiet --eval '
let initialized = true;
try {
	db.adminCommand({ replSetGetStatus: 1 });
} catch (e) {
	if (e.codeName !== "NotYetInitialized") throw e;
	initialized = false;
}
if (!initialized) {
	rs.initiate({
		_id: process.env.DPSRV_MONGO_CLUSTER,
		members: [ { _id: 0, host: process.env.DPSRV_MONGO_SELF, priority: 1 } ]
	});
}
initialized ? "initialized" : "initiated"
'

# Make this node the only electable member. Reconfig has to run on the current primary,
# and a primary cannot make itself unelectable, so a handover takes two passes:
#  1. on the old primary: raise this node to priority 2, priority takeover elects it
#  2. on this node, once primary: this node to priority 1, everybody else to 0
function reconcile() {
	local primary=$( mongo-local --quiet --eval 'db.hello().primary || ""' )
	if [ -z "$primary" ]; then
		echo "pending"
		return
	fi

	DPSRV_MONGO_PRIMARY=$primary mongo ${primary%:*} --quiet --eval '
	const self = process.env.DPSRV_MONGO_SELF;
	const primary = process.env.DPSRV_MONGO_PRIMARY;
	const conf = rs.conf();
	if (!conf.members.some(m => m.host === self)) {
		throw new Error(self + " is not a member of " + conf._id);
	}
	let changed = false;
	for (const m of conf.members) {
		let priority = 0;
		if (m.host === self) {
			priority = primary === self ? 1 : 2;
		} else if (m.host === primary) {
			priority = m.priority;
		}
		if (m.priority !== priority) {
			m.priority = priority;
			changed = true;
		}
	}
	if (changed) {
		rs.reconfig(conf);
	}
	primary === self && !changed ? "done" : "pending"
	' | tail -1
}

for i in $(seq 60); do
	[ "$(reconcile)" = "done" ] && break
	sleep 2
done
[ "$(reconcile)" = "done" ]

$SWD/init-dbs.sh
