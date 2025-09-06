
if [ -z $DPSRV_DOMAIN ]; then
	. <( cat /proc/1/environ | tr '\0' '\n' )
fi

main=$DPSRV_MONGO_CLUSTER.$DPSRV_DOMAIN
node=${DPSRV_REGION}-${DPSRV_NODE}.$DPSRV_DOMAIN

DPSRV_MONGO_TLS=${DPSRV_MONGO_TLS:-true}

MONGO_INITDB_ROOT_USERNAME_FILE=/etc/mongo/admin-username
MONGO_INITDB_ROOT_PASSWORD_FILE=/etc/mongo/admin-password

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] && [ -f "$MONGO_INITDB_ROOT_USERNAME_FILE" ]; then
    MONGO_INITDB_ROOT_USERNAME=$(cat $MONGO_INITDB_ROOT_USERNAME_FILE)
fi

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] && [ -f "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
    MONGO_INITDB_ROOT_PASSWORD=$(cat $MONGO_INITDB_ROOT_PASSWORD_FILE)
fi

function mongo() {
	local host=$1
	if [ -z $host ]; then
		echo "Usage: $FUNCNAME <hostname>"
		echo " e.g.: $FUNCNAME localhost"
		return 
	fi
	shift
	uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@$host:27017/admin?tls=$DPSRV_MONGO_TLS&tlsInsecure=true&tlsCertificateKeyFile=/etc/mongo/cert.pem"
	mongosh "$uri" "$@"
}

function mongo-local() {
	mongo localhost "$@"
}

function mongo-main() {
	mongo $main.$DPSRV_DOMAIN "$@"
}

