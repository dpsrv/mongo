#!/bin/bash -e

MONGO_INITDB_ROOT_USERNAME_FILE=$DPSRV_HOME/rc/secrets/mongo/conf/admin-username
MONGO_INITDB_ROOT_PASSWORD_FILE=$DPSRV_HOME/rc/secrets/mongo/conf/admin-password

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] && [ -f "$MONGO_INITDB_ROOT_USERNAME_FILE" ]; then
	MONGO_INITDB_ROOT_USERNAME=$(cat $MONGO_INITDB_ROOT_USERNAME_FILE)
fi

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] && [ -f "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
	MONGO_INITDB_ROOT_PASSWORD=$(cat $MONGO_INITDB_ROOT_PASSWORD_FILE)
fi

#admin_uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@localhost:27017/admin"
#admin_uri="mongodb://$MONGO_INITDB_ROOT_USERNAME@localhost:27017/admin?tls=true&authMechanism=MONGODB-X509&tlscertificatekeyfile=/etc/mongo/cert.pem"

admin_uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@localhost:27017/admin"
docker exec -it dpsrv-mongo mongosh --tls --tlsCertificateKeyFile /etc/mongo/cert.pem --tlsAllowInvalidCertificates "$admin_uri" 

