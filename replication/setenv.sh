
if [ -z $DPSRV_DOMAIN ]; then
	. <( cat /proc/1/environ | tr '\0' '\n' )
fi

main=mongo-main.$DPSRV_DOMAIN
node=${DPSRV_REGION}-${DPSRV_NODE}.$DPSRV_DOMAIN

MONGO_INITDB_ROOT_USERNAME_FILE=/etc/mongo/admin-username
MONGO_INITDB_ROOT_PASSWORD_FILE=/etc/mongo/admin-password

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] && [ -f "$MONGO_INITDB_ROOT_USERNAME_FILE" ]; then
    MONGO_INITDB_ROOT_USERNAME=$(cat $MONGO_INITDB_ROOT_USERNAME_FILE)
fi

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] && [ -f "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
    MONGO_INITDB_ROOT_PASSWORD=$(cat $MONGO_INITDB_ROOT_PASSWORD_FILE)
fi

MONGO_ADMIN_URI="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@localhost:27017/admin?tls=true&tlsInsecure=true&tlsCertificateKeyFile=/etc/mongo/cert.pem"

function mongo() {
	mongosh "$MONGO_ADMIN_URI" "$@"
}

