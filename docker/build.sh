#!/bin/bash -ex

SWD=$(dirname $0)

image=$(yq 'select(.metadata.name == "mongodb")  | .spec.template.spec.containers[] | select(.name == "mongodb") |  .image' $SWD/k8s/03-sts.yaml)
export tag=${image##*:}

docker compose build

docker push $image

kubectl -n dpsrv rollout restart sts mongodb
