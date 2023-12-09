#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo main

mongo --quiet --eval 'rs.initialize(
   {
      _id: "dpsrv",
      members: [
         { _id: 0, host : "'"$DPSRV_REGION-$DPSRV_NODE.$DPSRV_DOMAIN"':27017" }
      ]
   }
)' 

# mongo --quiet --eval 'rs.conf()' 

