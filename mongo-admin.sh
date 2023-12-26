#!/bin/bash -e

MONGO_INITDB_ROOT_USERNAME_FILE=$DPSRV_HOME/rc/secrets/mongo/conf/admin-username
MONGO_INITDB_ROOT_PASSWORD_FILE=$DPSRV_HOME/rc/secrets/mongo/conf/admin-password

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] && [ -f "$MONGO_INITDB_ROOT_USERNAME_FILE" ]; then
	MONGO_INITDB_ROOT_USERNAME=$(cat $MONGO_INITDB_ROOT_USERNAME_FILE)
fi

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] && [ -f "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
	MONGO_INITDB_ROOT_PASSWORD=$(cat $MONGO_INITDB_ROOT_PASSWORD_FILE)
fi

admin_uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@mongo-main.dpsrv.me:27017/admin?tls=true&tlsInsecure=true&tlsCertificateKeyFile=/etc/mongo/cert.pem"

docker exec -it dpsrv-mongo mongosh "$admin_uri" 

