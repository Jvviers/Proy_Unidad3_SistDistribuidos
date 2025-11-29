#!/bin/bash
set -e

until mysqladmin ping -h mysql-primary -uroot -proot --silent; do
  echo "Esperando al primario MySQL..."
  sleep 2
done

FILE=""
POS=""
while true; do
  STATUS=$(mysql -h mysql-primary -uroot -proot -N -e "SHOW BINARY LOG STATUS;" 2>/dev/null || true)
  FILE=$(echo "$STATUS" | awk 'NR==1 {print $1}')
  POS=$(echo "$STATUS" | awk 'NR==1 {print $2}')
  if [ -n "$FILE" ] && [ -n "$POS" ]; then
    break
  fi
  echo "Esperando binlog disponible..."
  sleep 2
done

mysql -uroot -proot <<EOF
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='mysql-primary',
  SOURCE_USER='repl',
  SOURCE_PASSWORD='replpass',
  GET_SOURCE_PUBLIC_KEY=1,
  SOURCE_LOG_FILE='$FILE',
  SOURCE_LOG_POS=$POS;
START REPLICA;
EOF
