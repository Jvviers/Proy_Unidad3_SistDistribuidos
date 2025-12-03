#!/bin/sh
set -eu

PRIMARY_HOST=${PRIMARY_HOST:-mariadb-primary}
REPLICA_HOST=${REPLICA_HOST:-mariadb-replica}
ROOT_PASS=${MYSQL_ROOT_PASSWORD:-root}
REPL_USER=${REPL_USER:-repl}
REPL_PASS=${REPL_PASS:-replpass}
CHECK_INTERVAL=${CHECK_INTERVAL:-5}
HAPROXY_SOCKET=/var/run/haproxy/admin.sock

log(){ echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

resolve_addr(){
  getent hosts "$1" | awk '{print $1}' | head -n1
}

promote_replica(){
  log "Promoviendo replica ${REPLICA_HOST}..."
  mysql -h"${REPLICA_HOST}" -u"${REPL_USER}" -p"${REPL_PASS}" -e "STOP SLAVE; RESET SLAVE ALL; SET GLOBAL read_only=0;" || {
    log "Error al promover replica"; return 1; }
  if [ -S "$HAPROXY_SOCKET" ]; then
    ADDR=$(resolve_addr "$REPLICA_HOST")
    [ -z "$ADDR" ] && ADDR="$REPLICA_HOST"
    echo "disable server mariadb_cluster/primary" | socat stdio "$HAPROXY_SOCKET" || true
    echo "set server mariadb_cluster/primary addr ${ADDR} port 3306" | socat stdio "$HAPROXY_SOCKET" || true
    echo "enable server mariadb_cluster/primary" | socat stdio "$HAPROXY_SOCKET" || true
    log "HAProxy actualizado para usar ${REPLICA_HOST} como primary"
  else
    log "Socket de HAProxy no encontrado; omitir recarga"
  fi
}

check_primary(){
  mysqladmin -h"${PRIMARY_HOST}" -uroot -p"${ROOT_PASS}" --connect-timeout=3 ping >/dev/null 2>&1
}

while true; do
  if check_primary; then
    sleep "$CHECK_INTERVAL"; continue
  fi
  log "Primario ${PRIMARY_HOST} no responde. Intentando promover replica";
  promote_replica || log "Promocion fallo"
  sleep "$CHECK_INTERVAL"
done
