#!/bin/bash -e

MONGO_INITDB_ROOT_USERNAME_FILE=$DPSRV_HOME/rc/secrets/mongo/conf/admin-username
MONGO_INITDB_ROOT_PASSWORD_FILE=$DPSRV_HOME/rc/secrets/mongo/conf/admin-password

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] && [ -f "$MONGO_INITDB_ROOT_USERNAME_FILE" ]; then
	MONGO_INITDB_ROOT_USERNAME=$(cat $MONGO_INITDB_ROOT_USERNAME_FILE)
fi

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] && [ -f "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
	MONGO_INITDB_ROOT_PASSWORD=$(cat $MONGO_INITDB_ROOT_PASSWORD_FILE)
fi

. $DPSRV_HOME/rc/bin/dpsrv.sh

MONGO_HOST=${MONGO_HOST:-mongo-main.dpsrv.me}
if [ -x /usr/bin/mongosh ]; then
	admin_uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@$MONGO_HOST:27017/admin?tls=true&tlsInsecure=true&tlsCertificateKeyFile=$DPSRV_HOME/rc/secrets/mongo/conf/cert.pem"
	mongosh "$admin_uri"
else
	admin_uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@$MONGO_HOST:27017/admin?tls=true&tlsInsecure=true&tlsCertificateKeyFile=/etc/mongo/cert.pem"

	container=$(dpsrv-list | grep ' dpsrv-mongo-' | awk '{ print $3 }')
	docker exec -it $container mongosh "$admin_uri"
fi

