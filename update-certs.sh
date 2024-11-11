#!/bin/bash -e

. /opt/replication/setenv.sh

files="/etc/letsencrypt/live/domain/privkey.pem /etc/letsencrypt/live/domain/cert.pem"

cat $files > /etc/mongo/cert.pem
last=$( ls -1t $files | head -1 | xargs date +%s -r )

while true; do
	latest=$( ls -1t $files | head -1 | xargs date +%s -r )
	sleep 60

	if [ $latest -gt $last ]; then
		last=$latest
		mongo-local --eval 'db.rotateCertificates();'
	fi

done &
