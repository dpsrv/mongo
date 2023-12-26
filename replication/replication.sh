#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

if [ $DPSRV_MONGO_NODE != true ]; then
	touch /tmp/replication.offline
else
	rm -f /tmp/replication.offline || true
fi

while true; do
	if [ -f /tmp/replication.offline ]; then
		$SWD/offline.sh 2>&1 | xargs echo "$(date +%Y-%m-%d\ %H:%M:%S)"
		sleep 60
		continue
	fi

	host $main | grep -v NXDOMAIN | sort > /tmp/replication.host 2>/dev/null
	if diff -q /tmp/replication.host /tmp/replication.last-host 2>/dev/null; then
		sleep 60
		continue
	fi

	unset complete
	if grep -q $node /tmp/replication.host; then
		$SWD/main.sh && complete=true 2>&1 | xargs echo "$(date +%Y-%m-%d\ %H:%M:%S)"
	else
		$SWD/replica.sh && complete=true 2>&1 | xargs echo "$(date +%Y-%m-%d\ %H:%M:%S)"
	fi

	if [ "$complete" = "true" ]; then
		cp /tmp/replication.host /tmp/replication.last-host
	fi

	sleep 30
done 

