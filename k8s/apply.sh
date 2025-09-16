#!/bin/bash -e

SWD=$(dirname $0)
for yaml in $SWD/*.yaml; do
	cat $yaml | envsubst | kubectl apply -f -
done
