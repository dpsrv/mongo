#!/bin/bash -ex

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

echo main


conf=$( mongo --quiet --eval 'EJSON.stringify(rs.conf())' )
echo "$conf"

exit
mongo --quiet --eval 'rs.initiate(
   {
      _id: "dpsrv",
      members: [
         { _id: 0, host : "'"$DPSRV_REGION-$DPSRV_NODE.$DPSRV_DOMAIN"':27017" }
      ]
   }
)' 


