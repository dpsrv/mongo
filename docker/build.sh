#!/bin/bash -ex

SWD=$(dirname $0)

cd $SWD

image=$(yq 'select(.metadata.name == "mongodb")  | .spec.template.spec.containers[] | select(.name == "mongodb") |  .image' ../k8s/03-sts.yaml)
export tag=${image##*:}

docker compose build

docker push $image

while read -u 3 node_id; do
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -n root@$node_id.$DPSRV_DOMAIN "k3s ctr images ls|awk '{ print \$1 }'|grep '$image\$' | xargs -L1 k3s ctr images rm " &
done 3< <(kubectl get nodes -o json|jq -r '.items[].metadata.name')
wait

kubectl -n dpsrv rollout restart sts mongodb
