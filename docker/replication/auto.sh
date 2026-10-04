#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

export DPSRV_MONGO_SELF="$node:27017"
export DPSRV_MONGO_REMOVE_AFTER=${DPSRV_MONGO_REMOVE_AFTER:-900}

primary=$(find_primary)

if [ -z "$primary" ]; then
	# Only the bootstrap node initiates, and only if no reachable peer has a replica set yet
	if [ -n "$main" ]; then
		bootstrap=${main%%.*}
	else
		bootstrap=${node%%.*}
		bootstrap=${bootstrap%-*}-0
	fi
	[ "${node%%.*}" = "$bootstrap" ] || exit 0

	for peer in $(peers); do
		set_name=$( mongo $peer --quiet --eval 'db.hello().setName || ""' )
		if [ -n "$set_name" ]; then
			echo "$peer is already a member of $set_name"
			exit 0
		fi
	done

	mongo-local --quiet --eval '
	rs.initiate({
		_id: process.env.DPSRV_MONGO_CLUSTER,
		members: [ { _id: 0, host: process.env.DPSRV_MONGO_SELF, priority: 1 } ]
	}).ok
	'
	exit 0
fi

if [ "$primary" != "$DPSRV_MONGO_SELF" ]; then
	# Register with the primary, it takes care of the rest
	mongo ${primary%:*} --quiet --eval '
	const self = process.env.DPSRV_MONGO_SELF;
	if (!rs.conf().members.some(m => m.host === self)) {
		rs.add({ host: self, priority: 1 });
	}
	'
	exit 0
fi

# This node is primary: make every member electable and drop members that have been gone for too long
mongo-local --quiet --eval '
const graceMillis = Number(process.env.DPSRV_MONGO_REMOVE_AFTER) * 1000;
const conf = rs.conf();
const status = rs.status();
const now = Date.now();
const upSince = now - status.members.find(m => m.self).uptime * 1000;

// A reconfig may only remove one voting member at a time
const dead = status.members.find(m => graceMillis > 0 && !m.self && m.health === 0
	&& now - Math.max(m.lastHeartbeatRecv ? m.lastHeartbeatRecv.getTime() : 0, upSince) > graceMillis);

let changed = false;
if (dead) {
	print("Removing " + dead.name + ", unreachable since " + dead.lastHeartbeatRecv);
	conf.members = conf.members.filter(m => m.host !== dead.name);
	changed = true;
}
for (const m of conf.members) {
	if (m.priority !== 1) {
		m.priority = 1;
		changed = true;
	}
}
if (changed) {
	rs.reconfig(conf);
}
'

$SWD/init-dbs.sh
