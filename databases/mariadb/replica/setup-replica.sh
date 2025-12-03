#!/bin/sh
set -eux

PRIMARY_HOST=${PRIMARY_HOST:-mariadb-primary}
PRIMARY_PORT=${PRIMARY_PORT:-3306}
REPL_USER=${REPL_USER:-repl}
REPL_PASS=${REPL_PASS:-replpass}
ORIGINAL_ENTRYPOINT=/usr/local/bin/docker-entrypoint.sh
LOCAL_HOST=127.0.0.1
LOCAL_PORT=3306

# Usa mysql con conexion TCP para evitar socket local
mysql_cmd() {
  mysql -h"${PRIMARY_HOST}" -P"${PRIMARY_PORT}" -u"${REPL_USER}" -p"${REPL_PASS}" "$@"
}

# Levantar MariaDB usando el entrypoint oficial en segundo plano
"${ORIGINAL_ENTRYPOINT}" mysqld --skip-slave-start &
MYSQL_PID=$!

# Esperar replica local
until mysqladmin ping -h"$LOCAL_HOST" -P"$LOCAL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do
  sleep 2
done

# Esperar primario
until mysqladmin ping -h"$PRIMARY_HOST" -P"$PRIMARY_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do
  sleep 2
done

# Clonar datos iniciales antes de configurar la replicacion
mysqldump -h"$PRIMARY_HOST" -P"$PRIMARY_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --databases "$MYSQL_DATABASE" \
  | mysql -h"$LOCAL_HOST" -P"$LOCAL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD"

# Crear usuario de replica local para que el watchdog pueda promover
mysql -h"$LOCAL_HOST" -P"$LOCAL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS '${REPL_USER}'@'%' IDENTIFIED BY '${REPL_PASS}'; GRANT ALL PRIVILEGES ON *.* TO '${REPL_USER}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"

# Obtener estado del primario con usuario de replicacion despues del volcado
MASTER_STATUS=$(mysql_cmd -e "SHOW MASTER STATUS\\G")
FILE=$(echo "$MASTER_STATUS" | awk '/File/ {print $2}')
POS=$(echo "$MASTER_STATUS" | awk '/Position/ {print $2}')

mysql -h"$LOCAL_HOST" -P"$LOCAL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" -e "STOP SLAVE; RESET SLAVE ALL; CHANGE MASTER TO MASTER_HOST='${PRIMARY_HOST}', MASTER_USER='${REPL_USER}', MASTER_PASSWORD='${REPL_PASS}', MASTER_PORT=${PRIMARY_PORT}, MASTER_LOG_FILE='${FILE}', MASTER_LOG_POS=${POS}; START SLAVE;" || exit 1

echo "Replica configurada."
wait "$MYSQL_PID"
