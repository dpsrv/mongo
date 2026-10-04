
if [ -z $DPSRV_DOMAIN ]; then
	. <( cat /proc/1/environ | tr '\0' '\n' )
fi

main=$(cat /mnt/mongo/cfg/MONGODB_PRIMARY 2>/dev/null || true)
node=$(hostname -f)

# MANUAL: $main is the only electable member
# AUTO:   all members are electable, $main only bootstraps the replica set
mode=$(cat /mnt/mongo/cfg/MONGODB_REPLICATION_MODE 2>/dev/null || echo ${DPSRV_MONGO_REPLICATION_MODE:-MANUAL})
mode=$(echo $mode | tr a-z A-Z)

# Headless service resolving to all peers, used for discovery in AUTO mode
service=${DPSRV_MONGO_SERVICE:-$(hostname -d)}

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
	uri="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@$host:27017/admin?tls=$DPSRV_MONGO_TLS&tlsInsecure=true&tlsCertificateKeyFile=/etc/mongo/cert.pem&serverSelectionTimeoutMS=5000&connectTimeoutMS=5000"
	# Keep mongosh state out of /data/db, the image entrypoint needs it owned by mongodb
	HOME=/root mongosh "$uri" "$@"
}

function mongo-local() {
	mongo localhost "$@"
}

function mongo-main() {
	mongo $main "$@"
}

# IPs of all peers currently registered with the headless service, including this node
function peers() {
	getent ahostsv4 $service | awk '{ print $1 }' | sort -u
}

# Prints host:port of the current primary as seen by $main or any peer, nothing if there is none
function find_primary() {
	local peer
	local primary
	for peer in $main $(peers); do
		primary=$( mongo $peer --quiet --eval 'db.hello().primary || ""' 2>/dev/null ) || continue
		if [ -n "$primary" ]; then
			echo $primary
			return
		fi
	done
}

