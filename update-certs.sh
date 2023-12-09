#!/bin/bash -ex

cat /etc/letsencrypt/live/domain/privkey.pem /etc/letsencrypt/live/domain/cert.pem > /etc/mongo/cert.pem

while true; do
	echo "Checking certs"
	sleep 120
done &
