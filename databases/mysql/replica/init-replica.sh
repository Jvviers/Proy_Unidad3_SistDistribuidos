#!/bin/bash
set -e

PRIMARY_HOST=${PRIMARY_HOST:-mysql-primary}
PRIMARY_PORT=${PRIMARY_PORT:-3306}
REPL_USER=${REPL_USER:-repl}
REPL_PASS=${REPL_PASS:-replpass}
ROOT_PASS=${MYSQL_ROOT_PASSWORD:-root}

echo "Esperando primario ${PRIMARY_HOST}:${PRIMARY_PORT}..."
until mysqladmin -h"$PRIMARY_HOST" -P"$PRIMARY_PORT" -uroot -p"$ROOT_PASS" --silent ping; do
  sleep 2
done

echo "Clonando datos iniciales desde primario..."
mysqldump -h"$PRIMARY_HOST" -P"$PRIMARY_PORT" -uroot -p"$ROOT_PASS" --single-transaction --databases "$MYSQL_DATABASE" \
  | mysql -uroot -p"$ROOT_PASS"

echo "Obteniendo estado del primario..."
MASTER_STATUS=$(mysql -h"$PRIMARY_HOST" -P"$PRIMARY_PORT" -uroot -p"$ROOT_PASS" -e "SHOW BINARY LOG STATUS\\G")
FILE=$(echo "$MASTER_STATUS" | awk '/File/ {print $2}')
POS=$(echo "$MASTER_STATUS" | awk '/Position/ {print $2}')

echo "Configurando replica..."
mysql -uroot -p"$ROOT_PASS" <<SQL
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='${PRIMARY_HOST}',
  SOURCE_USER='${REPL_USER}',
  SOURCE_PASSWORD='${REPL_PASS}',
  SOURCE_PORT=${PRIMARY_PORT},
  SOURCE_LOG_FILE='${FILE}',
  SOURCE_LOG_POS=${POS},
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
SET GLOBAL read_only=1;
SET GLOBAL super_read_only=1;
SQL

echo "Replica configurada."
