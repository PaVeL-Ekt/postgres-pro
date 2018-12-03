#!/bin/bash
set -e

function enableConfOption()
{
	local FILE=${1:-}
	if [ -f "$FILE" ]; then
		local OPTION=${2:-}
		if [ ! -z "$OPTION" ]; then
			sed -ri "s!^#($OPTION\s*=\s*\S+.*)!\1!" "$FILE"
		fi
	fi
}

function disableConfOption()
{
	local FILE=${1:-}
	if [ -f "$FILE" ]; then
		local OPTION=${2:-}
		if [ ! -z "$OPTION" ]; then
			sed -ri "s!^($OPTION\s*=\s*\S+.*)!#\1!" "$FILE"
		fi
	fi
}

function setConfOption()
{
	local FILE=${1:-}
	if [ -f "$FILE" ]; then
		local OPTION=${2:-}
		if [ ! -z "$OPTION" ]; then
			local VALUE=${3:-}
			sed -ri "s!^#?($OPTION)\s*=\s*\S+.*!\1 = $VALUE!" "$FILE"
		fi
	fi
}

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"
	chown -R postgres "$PGDATA"

	mkdir -p /run/postgresql
	chmod g+s /run/postgresql
	chown -R postgres /run/postgresql

	mkdir -p "$PGLOG"
	chmod g+s "$PGLOG"
	chmod a+rX "$PGLOG"

	# runs scripts every time before init or starts postgres professional
	for f in /docker-entrypoint-init.d/*; do
		case "$f" in
			*.sh) echo "$0: running $f"; . "$f" ;;
			*)    echo "$0: ignoring $f" ;;
		esac
		echo
	done

	# look specifically for PG_VERSION, as it is expected in the DB dir
	if [ ! -s "$PGDATA/PG_VERSION" ]; then
		eval "gosu postgres initdb $POSTGRES_INITDB_ARGS"

		# check password first so we can output the warning before postgres
		# messes it up
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.

				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN

			pass=
			authMethod=trust
		fi

		{ echo; echo "host all all 0.0.0.0/0 $authMethod"; } | gosu postgres tee -a "$PGDATA/pg_hba.conf" > /dev/null

		CONF=$PGDATA/postgresql.conf
		setConfOption "$CONF" "listen_addresses" "'*'"

		# Init log if needed
		if [ ${LOG_ENABLED:-0} -eq 1 ]; then
			setConfOption "$CONF" "logging_collector" "on"
			enableConfOption "$CONF" "log_destination"
			setConfOption "$CONF" "log_directory" "'$PGLOG'"
			enableConfOption "$CONF" "log_filename"
			setConfOption "$CONF" "log_truncate_on_rotation" "on"
			enableConfOption "$CONF" "log_min_messages"
			setConfOption "$CONF" "log_min_duration_statement" "0"
			setConfOption "$CONF" "log_duration" "on"
			setConfOption "$CONF" "log_checkpoints" "on"
			setConfOption "$CONF" "log_connections" "on"
			setConfOption "$CONF" "log_disconnections" "on"
			setConfOption "$CONF" "log_lock_waits" "on"
			setConfOption "$CONF" "log_statement" "'all'"
			setConfOption "$CONF" "log_temp_files" "0"
			setConfOption "$CONF" "log_line_prefix" "'%m [%p] db/user/app: \"%d/%u/%a\" '"
			chmod a+rwX $PGLOG
		fi

		# internal start of server in order to allow set-up using psql-client
		# does not listen on external TCP/IP and waits until start finishes
		gosu postgres pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses='localhost'" \
			-w start

		: ${POSTGRES_USER:=postgres}
		: ${POSTGRES_DB:=$POSTGRES_USER}
		export POSTGRES_USER POSTGRES_DB

		psql=( psql -v ON_ERROR_STOP=1 )

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			"${psql[@]}" --username postgres <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi

		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi
		"${psql[@]}" --username postgres <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo

		psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

		echo
		echo 'PostgreSQL init process complete; ready for start up.'
		echo
	fi

	exec gosu postgres "$@"
fi

exec "$@"
