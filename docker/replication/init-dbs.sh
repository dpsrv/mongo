#!/bin/bash -e

SWD=$( cd $(dirname $0); pwd )

. $SWD/setenv.sh

function get_db_user() {
	local db=$1
	local user=$2
	mongo-local --quiet --eval "db.getSiblingDB('$db').getUser('$user')"
}

function create_db_user() {
	local db=$1
	local user=$2
	local pass=$3
	mongo-local --quiet --eval "db.getSiblingDB('$db').createUser({user: '$user', pwd: '$pass', roles: [{role: 'readWrite', db: '$db'}]});"
}

while read db user pass; do
	db_user=$(get_db_user $db $user)
	if [ "$db_user" != "null" ]; then
		echo "$db.$user exists: $db_user"
		continue
	fi
	echo "$db.$user creating"
	create_db_user $db $user $pass
done < /etc/mongo/dbs

