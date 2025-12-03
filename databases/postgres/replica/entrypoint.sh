#!/bin/bash
set -e

PRIMARY_HOST=${PRIMARY_HOST:-postgres-primary}
REPL_USER=${REPL_USER:-replication}
REPL_PASS=${REPL_PASS:-replpass}
PGPASSWORD=${REPL_PASS}
export PGPASSWORD

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Esperando primario ${PRIMARY_HOST}..."
  until pg_isready -h "$PRIMARY_HOST" -U "$REPL_USER"; do
    sleep 2
  done
  echo "Inicializando réplica desde ${PRIMARY_HOST}..."
  pg_basebackup -h "$PRIMARY_HOST" -D "$PGDATA" -U "$REPL_USER" -Fp -Xs -P -R
fi

exec /usr/local/bin/docker-entrypoint.sh postgres
