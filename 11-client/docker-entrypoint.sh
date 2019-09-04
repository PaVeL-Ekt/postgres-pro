#!/bin/bash
set -e

# runs scripts every time before init or starts postgres professional
for f in /docker-entrypoint-init.d/*; do
	case "$f" in
		*.sh) echo "$0: running $f"; . "$f" ;;
		*)    echo "$0: ignoring $f" ;;
	esac
	echo
done
# internal start of server in order to allow set-up using psql-client
# does not listen on external TCP/IP and waits until start finishes
: ${POSTGRES_HOST:=localhost}
: ${POSTGRES_USER:=postgres}
: ${POSTGRES_PASS:=}
: ${POSTGRES_DB:=$POSTGRES_USER}
: ${PGPASSWORD:=$POSTGRES_PASS}
export POSTGRES_HOST POSTGRES_USER POSTGRES_PASS POSTGRES_DB PGPASSWORD

gosu postgres psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB"

exec "$@"
