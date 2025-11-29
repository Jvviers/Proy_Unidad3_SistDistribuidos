#!/bin/bash
set -e

STATUS=""
while true; do
  echo "Esperando al primario MariaDB..."
  STATUS=$(mysql -h mariadb-primary -uroot -proot -N -e "SHOW MASTER STATUS;" 2>/dev/null || true)
  FILE=$(echo "$STATUS" | awk 'NR==1 {print $1}')
  POS=$(echo "$STATUS" | awk 'NR==1 {print $2}')
  if [ -n "$FILE" ] && [ -n "$POS" ]; then
    break
  fi
  sleep 2
done

mysql -uroot -proot <<EOF
STOP SLAVE;
RESET SLAVE ALL;
CHANGE MASTER TO
  MASTER_HOST='mariadb-primary',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpass',
  MASTER_LOG_FILE='$FILE',
  MASTER_LOG_POS=$POS;
START SLAVE;
EOF
