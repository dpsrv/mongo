#!/bin/bash -e

SWD=$(dirname $0)
for yaml in *.yaml; do
	cat $yaml | envsubst | kubectl apply -f -
done
