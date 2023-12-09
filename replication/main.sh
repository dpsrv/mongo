#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo main

# mongo --quiet --eval 'rs.initialize()' 
# mongo --quiet --eval 'rs.conf()' 

