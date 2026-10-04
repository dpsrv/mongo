#!/bin/bash -e
#
# Replication integration tests.
#
# Brings up a number of mongodb nodes in docker, running the same entrypoint and
# replication scripts as the k8s statefulset, then shifts the main node between them in MANUAL
# mode, and fails nodes over in AUTO mode.
#
# Usage: test/integration.sh [test ...]
#
# Environment:
#   NODES            number of nodes to bring up (default 3, minimum 3)
#   MONGO_VERSION    mongo version under test (default: Dockerfile default)
#   FROM_VERSION     mongo version the upgrade test starts from (default 8.0.3)
#   KEEP=1           leave containers running after the tests

SWD=$( cd $(dirname $0); pwd )

NODES=${NODES:-3}
FROM_VERSION=${FROM_VERSION:-8.0.3}
PREFIX=dpsrv-mongo-test
DOMAIN=mongodb.test
CLUSTER=dpsrv
INTERVAL=3
REMOVE_AFTER=15
TIMEOUT=${TIMEOUT:-120}
WORK=$(mktemp -d /tmp/$PREFIX.XXXXXX)

ALL_TESTS="bootstrap replicates_writes creates_users shift_main offline_online restart_secondary restart_main scale_up mode_switch
	auto_bootstrap auto_failover auto_offline_primary auto_scale_up auto_remove_dead upgrade"
TESTS=${*:-$ALL_TESTS}

[ $NODES -ge 3 ] || { echo "NODES must be at least 3"; exit 1; }

function log() {
	echo "$(date +%H:%M:%S) $*" >&2
}

function cleanup() {
	if [ "$KEEP" = "1" ]; then
		log "Keeping containers, work dir $WORK"
		return
	fi
	docker ps -aq --filter "label=$PREFIX" | xargs docker rm -f >/dev/null 2>&1 || true
	docker volume ls -q --filter "label=$PREFIX" | xargs docker volume rm >/dev/null 2>&1 || true
	docker network rm $PREFIX >/dev/null 2>&1 || true
	rm -rf $WORK
}
trap cleanup EXIT

function setup_fixtures() {
	mkdir -p $WORK/conf $WORK/letsencrypt $WORK/cfg

	openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=*.$DOMAIN" \
		-keyout $WORK/letsencrypt/privkey.pem -out $WORK/letsencrypt/cert.pem 2>/dev/null
	cp $WORK/letsencrypt/cert.pem $WORK/conf/ca.pem
	openssl rand -base64 756 > $WORK/conf/dpsrv.key

	printf 'app1 app1user app1pass\napp2 app2user app2pass\n' > $WORK/conf/dbs

	cat > $WORK/conf/mongod.conf <<-EOF
	net:
	  port: 27017
	  bindIpAll: true
	  tls:
	    mode: preferTLS
	    certificateKeyFile: /etc/mongo/cert.pem
	    CAFile: /etc/mongo/ca.pem
	    allowConnectionsWithoutCertificates: true
	    allowInvalidCertificates: true
	security:
	  keyFile: /etc/mongo/dpsrv.key
	  authorization: enabled
	EOF

	chmod -R go+r $WORK
}

function build_image() {
	local version=$1
	log "Building image for mongo $version"
	docker build -q ${version:+--build-arg MONGO_VERSION=$version} -t $PREFIX:${version:-default} $SWD/../docker >/dev/null
}

function host() {
	echo "mongodb-$1.$DOMAIN"
}

function container() {
	echo "$PREFIX-$1"
}

# start_node <ordinal> [image tag]
function start_node() {
	local i=$1
	local tag=${2:-default}
	docker rm -f $(container $i) >/dev/null 2>&1 || true
	docker volume create --label $PREFIX $PREFIX-data-$i >/dev/null
	docker run -d --label $PREFIX --name $(container $i) \
		--network $PREFIX --hostname $(host $i) --network-alias $(host $i) --network-alias $DOMAIN \
		-e DPSRV_DOMAIN=$DOMAIN \
		-e DPSRV_MONGO_CLUSTER=$CLUSTER \
		-e DPSRV_MONGO_TLS=false \
		-e DPSRV_MONGO_REPLICATION_INTERVAL=$INTERVAL \
		-e DPSRV_MONGO_REMOVE_AFTER=$REMOVE_AFTER \
		-e MONGO_INITDB_ROOT_USERNAME=admin \
		-e MONGO_INITDB_ROOT_PASSWORD=secret \
		-v $WORK/cfg:/mnt/mongo/cfg:ro \
		-v $PREFIX-data-$i:/data/db \
		-v $WORK/conf/mongod.conf:/etc/mongo.init/mongod.conf:ro \
		-v $WORK/conf/dpsrv.key:/etc/mongo.init/dpsrv.key:ro \
		-v $WORK/conf/ca.pem:/etc/mongo.init/ca.pem:ro \
		-v $WORK/conf/dbs:/etc/mongo.init/dbs:ro \
		-v $WORK/letsencrypt/cert.pem:/etc/letsencrypt/live/domain/cert.pem:ro \
		-v $WORK/letsencrypt/privkey.pem:/etc/letsencrypt/live/domain/privkey.pem:ro \
		$PREFIX:$tag >/dev/null
}

function stop_node() {
	docker stop -t 30 $(container $1) >/dev/null
}

function remove_node() {
	docker rm -f $(container $1) >/dev/null 2>&1 || true
	docker volume rm $PREFIX-data-$1 >/dev/null 2>&1 || true
}

# Equivalent of editing MONGODB_PRIMARY in the k8s configmap
function set_main() {
	echo $(host $1) > $WORK/cfg/MONGODB_PRIMARY
}

# Equivalent of editing MONGODB_REPLICATION_MODE in the k8s configmap
function set_mode() {
	echo $1 > $WORK/cfg/MONGODB_REPLICATION_MODE
}

# msh <ordinal> <js>
function msh() {
	local i=$1
	shift
	docker exec $(container $i) mongosh --quiet \
		"mongodb://admin:secret@localhost:27017/admin?tls=false" --eval "$*" 2>/dev/null
}

# Members as "<ordinal>:<priority>" sorted by ordinal, e.g. "0:1 1:0 2:0"
function members() {
	msh $1 'rs.conf().members.map(m => m.host.replace(/^mongodb-(\d+)\..*/, "$1") + ":" + m.priority).sort((a, b) => parseInt(a) - parseInt(b)).join(" ")'
}

function state() {
	msh $1 'rs.status().members.find(m => m.self).stateStr'
}

# wait_for <description> <expected> <command ...>
function wait_for() {
	local desc=$1
	local expected=$2
	shift 2
	local actual
	local deadline=$(( $(date +%s) + TIMEOUT ))
	while [ $(date +%s) -lt $deadline ]; do
		actual=$("$@" || true)
		[ "$actual" = "$expected" ] && return 0
		sleep 2
	done
	log "FAIL: $desc: expected '$expected', got '$actual'"
	return 1
}

function assert_eq() {
	local desc=$1
	local expected=$2
	local actual=$3
	if [ "$actual" != "$expected" ]; then
		log "FAIL: $desc: expected '$expected', got '$actual'"
		return 1
	fi
}

function expected_members() {
	local i
	local main=$1
	local count=${2:-$NODES}
	local out=()
	for (( i = 0; i < count; i++ )); do
		[ $i = $main ] && out+=("$i:1") || out+=("$i:0")
	done
	echo "${out[*]}"
}

# Waits until <main> is primary, every node is a member with the expected priority, and all secondaries are healthy
function wait_for_cluster() {
	local i
	local main=$1
	local count=${2:-$NODES}
	wait_for "node $main is primary" PRIMARY state $main
	wait_for "members with $main as main" "$(expected_members $main $count)" members $main
	for (( i = 0; i < count; i++ )); do
		[ $i = $main ] && continue
		wait_for "node $i is secondary" SECONDARY state $i
	done
}

# Ordinal of the primary as seen by node <i>, empty if there is none
function primary() {
	msh $1 'const p = db.hello().primary; p ? p.replace(/^mongodb-(\d+)\..*/, "$1") : ""'
}

# Prints "yes" once node <i> sees a primary other than <old>
function primary_is_not() {
	local p=$(primary $1)
	[ -n "$p" ] && [ "$p" != "$2" ] && echo yes
}

function healthy() {
	msh $1 '["PRIMARY", "SECONDARY"].includes(rs.status().members.find(m => m.self).stateStr)'
}

# All members with priority 1, e.g. "0:1 1:1 2:1", optionally without <except>
function electable_members() {
	local i
	local count=$1
	local except=$2
	local out=()
	for (( i = 0; i < count; i++ )); do
		[ "$i" = "$except" ] || out+=("$i:1")
	done
	echo "${out[*]}"
}

# Waits until <count> nodes are electable members with a primary, as seen by node <i>
function wait_for_auto_cluster() {
	local i
	local seen_by=$1
	local count=${2:-$NODES}
	wait_for "all members electable" "$(electable_members $count)" members $seen_by
	wait_for "a primary" yes primary_is_not $seen_by none
	for (( i = 0; i < count; i++ )); do
		wait_for "node $i is healthy" true healthy $i
	done
}

# start_cluster [image tag] [mode]
function start_cluster() {
	local i
	local tag=$1
	local mode=${2:-MANUAL}
	set_main 0
	set_mode $mode
	for (( i = 0; i < NODES; i++ )); do
		start_node $i $tag
	done
	if [ $mode = AUTO ]; then
		wait_for_auto_cluster 0
	else
		wait_for_cluster 0
	fi
}

function remove_all_nodes() {
	local i
	for (( i = 0; i <= NODES; i++ )); do
		remove_node $i
	done
}

function write_doc() {
	local i=$1
	local id=$2
	msh $i 'db.getSiblingDB("test").docs.insertOne({ _id: "'$id'" }, { writeConcern: { w: "majority" } }).acknowledged'
}

function read_doc() {
	local i=$1
	local id=$2
	msh $i 'db.getMongo().setReadPref("secondaryPreferred"); db.getSiblingDB("test").docs.findOne({ _id: "'$id'" })?._id ?? "missing"'
}

function assert_doc_everywhere() {
	local i
	local id=$1
	local count=${2:-$NODES}
	for (( i = 0; i < count; i++ )); do
		wait_for "doc $id replicated to node $i" $id read_doc $i $id
	done
}

### Tests

function test_bootstrap() {
	start_cluster
	assert_eq "replica set name" $CLUSTER "$(msh 0 'rs.conf()._id')"
	assert_eq "mongo version" "$(docker run --rm --entrypoint mongod $PREFIX:default --version | sed -n 's/^db version v//p')" "$(msh 0 'db.version()')"
}

function test_replicates_writes() {
	assert_eq "write on main" true "$(write_doc 0 replicates)"
	assert_doc_everywhere replicates
}

function test_creates_users() {
	assert_eq "app1user" app1user "$(msh 0 'db.getSiblingDB("app1").getUser("app1user")?.user')"
	assert_eq "app2user" app2user "$(msh 0 'db.getSiblingDB("app2").getUser("app2user")?.user')"
	assert_eq "app1user can write" true "$(docker exec $(container 0) mongosh --quiet \
		'mongodb://app1user:app1pass@localhost:27017/app1?tls=false' \
		--eval 'db.things.insertOne({}).acknowledged' 2>/dev/null)"
}

function test_shift_main() {
	local main
	for main in $(seq 1 $(( NODES - 1 ))) 0; do
		log "Shifting main to node $main"
		set_main $main
		wait_for_cluster $main
		assert_eq "write on node $main" true "$(write_doc $main shift-$main)"
		assert_doc_everywhere shift-$main
	done
	assert_doc_everywhere replicates
}

function test_offline_online() {
	local node=$(( NODES - 1 ))
	docker exec $(container $node) touch /tmp/replication.offline
	wait_for "node $node removed" "$(expected_members 0 $node)" members 0

	docker exec $(container $node) rm /tmp/replication.offline
	wait_for_cluster 0
	assert_doc_everywhere replicates
}

function test_restart_secondary() {
	stop_node 1
	assert_eq "write while secondary is down" true "$(write_doc 0 secondary-down)"
	docker start $(container 1) >/dev/null
	wait_for_cluster 0
	assert_doc_everywhere secondary-down
}

function test_restart_main() {
	stop_node 0
	docker start $(container 0) >/dev/null
	wait_for_cluster 0
	assert_eq "write after main restart" true "$(write_doc 0 main-restart)"
	assert_doc_everywhere main-restart
}

function test_scale_up() {
	start_node $NODES
	wait_for_cluster 0 $(( NODES + 1 ))
	assert_doc_everywhere replicates $(( NODES + 1 ))

	docker exec $(container $NODES) touch /tmp/replication.offline
	wait_for "node $NODES removed" "$(expected_members 0)" members 0
	remove_node $NODES
}

# Rolling upgrade from FROM_VERSION, the same order the statefulset uses: highest ordinal first
function test_mode_switch() {
	log "Switching to AUTO"
	set_mode AUTO
	wait_for_auto_cluster 0
	local p=$(primary 0)
	assert_eq "write in AUTO" true "$(write_doc $p mode-auto)"
	assert_doc_everywhere mode-auto

	log "Switching to MANUAL with node 1 as main"
	set_main 1
	set_mode MANUAL
	wait_for_cluster 1
	assert_eq "write in MANUAL" true "$(write_doc 1 mode-manual)"
	assert_doc_everywhere mode-manual
}

function test_auto_bootstrap() {
	remove_all_nodes
	start_cluster default AUTO
	assert_eq "bootstrap node is primary" 0 "$(primary 1)"
	assert_eq "write on primary" true "$(write_doc 0 auto)"
	assert_doc_everywhere auto
	assert_eq "app1user" app1user "$(msh 0 'db.getSiblingDB("app1").getUser("app1user")?.user')"
}

function test_auto_failover() {
	local old=$(primary 0)
	local other=$(( (old + 1) % NODES ))
	log "Stopping primary node $old"
	stop_node $old
	wait_for "new primary elected" yes primary_is_not $other $old
	local new=$(primary $other)
	assert_eq "write on new primary $new" true "$(write_doc $new failover)"

	docker start $(container $old) >/dev/null
	wait_for_auto_cluster $new
	assert_doc_everywhere failover
}

function test_auto_offline_primary() {
	local old=$(primary 0)
	docker exec $(container $old) touch /tmp/replication.offline
	wait_for "primary $old stepped down and removed" "$(electable_members $NODES $old)" members $(( (old + 1) % NODES ))

	docker exec $(container $old) rm /tmp/replication.offline
	wait_for_auto_cluster $(( (old + 1) % NODES ))
	assert_doc_everywhere failover
}

function test_auto_scale_up() {
	start_node $NODES
	wait_for_auto_cluster 0 $(( NODES + 1 ))
	assert_doc_everywhere failover $(( NODES + 1 ))
}

# Scale down: the pod and its volume go away for good
function test_auto_remove_dead() {
	remove_node $NODES
	wait_for "node $NODES removed after ${REMOVE_AFTER}s" "$(electable_members $NODES)" members 0
	local p=$(primary 0)
	assert_eq "write after removal" true "$(write_doc $p removed)"
	assert_doc_everywhere removed
}

function test_upgrade() {
	local i
	remove_all_nodes

	build_image $FROM_VERSION
	start_cluster $FROM_VERSION
	local from_fcv=$(msh 0 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 }).featureCompatibilityVersion.version')
	assert_eq "starting FCV" "${FROM_VERSION%.*}" "$from_fcv"
	assert_eq "write on $FROM_VERSION" true "$(write_doc 0 upgrade)"
	assert_doc_everywhere upgrade

	for (( i = NODES - 1; i >= 0; i-- )); do
		log "Upgrading node $i"
		stop_node $i
		start_node $i
		wait_for_cluster 0
	done

	local version=$(msh 0 'db.version()')
	local fcv=${version%.*}
	assert_eq "setFeatureCompatibilityVersion $fcv" 1 \
		"$(msh 0 'db.adminCommand({ setFeatureCompatibilityVersion: "'$fcv'", confirm: true }).ok')"
	for (( i = 0; i < NODES; i++ )); do
		wait_for "node $i FCV" $fcv msh $i 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 }).featureCompatibilityVersion.version'
		assert_eq "node $i version" $version "$(msh $i 'db.version()')"
	done
	assert_doc_everywhere upgrade

	set_main 1
	wait_for_cluster 1
	assert_eq "write after upgrade" true "$(write_doc 1 upgraded)"
	assert_doc_everywhere upgraded
}

### Main

setup_fixtures
docker network create --label $PREFIX $PREFIX >/dev/null
build_image

passed=0
failed=0
for t in $TESTS; do
	log "=== $t"
	start=$(date +%s)
	set +e
	( set -e; test_$t )
	rc=$?
	set -e
	if [ $rc = 0 ]; then
		log "PASS: $t ($(( $(date +%s) - start ))s)"
		passed=$(( passed + 1 ))
	else
		failed=$(( failed + 1 ))
		for c in $(docker ps -a --filter "label=$PREFIX" --format '{{.Names}}'); do
			log "--- $c replication log"
			docker logs $c 2>&1 | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} ' | grep -iE 'error|exception|fail' | tail -10 >&2
		done
		log "FAIL: $t"
		break
	fi
done

log "$passed passed, $failed failed"
[ $failed = 0 ]
