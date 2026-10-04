# mongo

### K8s Deployment
Do not apply yaml files directly, they need to run setenv first

### Replication
Every node runs `docker/replication/replication.sh`, which reconciles the replica set every
`DPSRV_MONGO_REPLICATION_INTERVAL` seconds (default 60):
- The node named in the `MONGODB_PRIMARY` configmap key initiates the replica set if needed, becomes primary
  with priority 1, makes all other members priority 0, and creates the users listed in `/etc/mongo/dbs`.
- Every other node adds itself to the replica set with priority 0.
- `touch /tmp/replication.offline` in a container removes that node from the replica set; delete the file to re-add it.

To move the primary, change `MONGODB_PRIMARY` in `k8s/01-configmap.yaml` and apply it. No restart is needed.

### Tests
`test/integration.sh` brings up mongodb nodes in docker using the same image and scripts, then
moves the primary between them, takes nodes offline, restarts nodes, adds a node, and does a rolling
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
