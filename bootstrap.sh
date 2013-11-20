#!/bin/bash

usage() {
    cat <<EOF
$0 prefix num_dbs admin_user password [bootstrap]

Initializes num_dbs on the specified cluter naming the databases
[prefix]0, [prefix]1, etc.

EOF
}

if [ $# -lt 4 ]; then
    usage
    exit 1;
fi

PREFIX=$1;
NUM_DB=$2;
ADMIN_USER=$3;
ADMIN_PASS=$4;
MAX=$(( $NUM_DB - 1 ));
BOOTSTRAP=$5;

sudo -u postgres psql -c "CREATE ROLE $ADMIN_USER WITH SUPERUSER
    LOGIN ENCRYPTED PASSWORD '$ADMIN_PASS';" $NEW_DB;

for i in $(seq 0 $MAX); do
    NEW_DB=${PREFIX}$i;
    sudo -u postgres psql -c "CREATE DATABASE $NEW_DB;"
done

if [ \! -z $BOOTSTRAP ]; then
    sudo -u postgres psql -f $BOOTSTRAP $NEW_DB;
fi
