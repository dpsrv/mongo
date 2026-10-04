#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

if [ -z "$DPSRV_MONGO_CLUSTER" ]; then
	exit
fi

interval=${DPSRV_MONGO_REPLICATION_INTERVAL:-60}

set -o pipefail

function log() {
	while read line; do echo "$(date +%Y-%m-%d\ %H:%M:%S) $line"; done
}

# Wait for the local mongod to accept connections
until mongo-local --quiet --eval 'db.hello().ok' >/dev/null 2>&1; do
	sleep 5
done

while true; do
	# Re-read the main node, it can be changed at runtime via the configmap
	. $SWD/setenv.sh

	if [ -f /tmp/replication.offline ]; then
		$SWD/offline.sh 2>&1 | log || true
	elif [ -z "$main" ]; then
		:
	elif getent hosts $main | grep -qwF "$node"; then
		# All scripts are idempotent, so reconcile on every pass
		$SWD/main.sh 2>&1 | log || true
	else
		$SWD/replica.sh 2>&1 | log || true
	fi

	sleep $interval
done
