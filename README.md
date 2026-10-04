# mongo

### K8s Deployment
Do not apply yaml files directly, they need to run setenv first

### Replication
Every node runs `docker/replication/replication.sh`, which reconciles the replica set every
`DPSRV_MONGO_REPLICATION_INTERVAL` seconds (default 60). The mode is set by `MONGODB_REPLICATION_MODE` in
`k8s/01-configmap.yaml` (or the `DPSRV_MONGO_REPLICATION_MODE` env var when there is no configmap), and can be
switched at runtime in either direction by applying the configmap. No restart is needed.

#### MANUAL (default)
- The node named in `MONGODB_PRIMARY` initiates the replica set if needed, becomes primary with priority 1,
  makes all other members priority 0, and creates the users listed in `/etc/mongo/dbs`.
- Every other node adds itself to the replica set with priority 0.
- To move the primary, change `MONGODB_PRIMARY`. There is no automatic failover: if the main node is down,
  there is no primary until it comes back or `MONGODB_PRIMARY` is changed.

#### AUTO
- All members have priority 1 and MongoDB elects the primary, so it fails over on its own.
- Nodes discover each other through the headless service (`DPSRV_MONGO_SERVICE`, default `hostname -d`)
  and add themselves to the replica set through the current primary.
- `MONGODB_PRIMARY` only picks the node that initiates a brand new replica set (ordinal 0 if unset).
  It does that only when no reachable peer is already part of a replica set.
- The primary creates the users and removes members that have been unreachable for `DPSRV_MONGO_REMOVE_AFTER`
  seconds (default 900, 0 disables), one per pass. That is what makes scaling the statefulset down work.
- Run at least 3 replicas, a majority of members has to be up to elect a primary.

#### Both modes
- `touch /tmp/replication.offline` in a container removes that node from the replica set (a primary steps down
  first); delete the file to re-add it.

### Tests
`test/integration.sh` brings up mongodb nodes in docker using the same image and scripts. In MANUAL mode it
moves the primary between them, takes nodes offline, restarts nodes, adds a node, and switches modes; in AUTO
mode it bootstraps, fails over, takes the primary offline, scales up and down. Finally it does a rolling
upgrade from `FROM_VERSION`.

```
test/integration.sh                    # all tests, 3 nodes
NODES=5 test/integration.sh            # more nodes
test/integration.sh bootstrap shift_main
FROM_VERSION=8.0.3 test/integration.sh upgrade
KEEP=1 test/integration.sh             # leave containers running for inspection
```

### Upgrading MongoDB
1. Check that featureCompatibilityVersion is set to the current version on the primary,
   e.g. `db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })` returns `8.0` before going to 9.0.
   If it is lower, run `db.adminCommand({ setFeatureCompatibilityVersion: "8.0", confirm: true })` first.
2. Bump `MONGO_VERSION` in `docker/Dockerfile` and the image tag in `k8s/03-sts.yaml`, run `test/integration.sh`.
3. `docker/build.sh` to build and push the new tag, then `k8s/apply.sh`. The statefulset restarts pods from the
   highest ordinal down, so secondaries go first.
4. Once every pod runs the new version: `db.adminCommand({ setFeatureCompatibilityVersion: "9.0", confirm: true })`.
