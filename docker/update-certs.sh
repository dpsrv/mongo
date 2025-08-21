#!/bin/bash -e

. /opt/replication/setenv.sh

files="/etc/letsencrypt/live/domain/privkey.pem /etc/letsencrypt/live/domain/cert.pem"

cat $files > /etc/mongo/cert.pem
chmod u=rw,og= /etc/mongo/cert.pem
chown mongodb:mongodb /etc/mongo/cert.pem

last=$( ls -1t $files | head -1 | xargs date +%s -r )

while true; do
	sleep 60

	latest=$( ls -1t $files | head -1 | xargs date +%s -r )

	if [ $latest -gt $last ]; then
		cat $files > /etc/mongo/cert.pem
		if mongo-local --eval 'db.rotateCertificates()'; then
			last=$latest
		fi
	fi
done &
