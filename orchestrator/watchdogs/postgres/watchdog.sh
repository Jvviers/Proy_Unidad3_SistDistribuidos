#!/bin/sh
set -eu

PRIMARY_HOST=${PRIMARY_HOST:-postgres-primary}
REPLICA_HOST=${REPLICA_HOST:-postgres-replica}
REPL_USER=${REPL_USER:-failover}
REPL_PASS=${REPL_PASS:-failover123}
CHECK_INTERVAL=${CHECK_INTERVAL:-5}
HAPROXY_SOCKET=/var/run/haproxy/admin.sock

log(){ echo "[$(date +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

check_primary(){
  PGPASSWORD=$REPL_PASS pg_isready -h "$PRIMARY_HOST" -U "$REPL_USER" >/dev/null 2>&1
}

resolve_addr(){
  getent hosts "$1" | awk '{print $1}' | head -n1
}

promote_replica(){
  log "Promoviendo replica ${REPLICA_HOST}..."
  PGPASSWORD=$REPL_PASS psql -h "$REPLICA_HOST" -U "$REPL_USER" -d postgres -c "SELECT pg_promote();" >/dev/null
  if [ -S "$HAPROXY_SOCKET" ]; then
    ADDR=$(resolve_addr "$REPLICA_HOST")
    [ -z "$ADDR" ] && ADDR="$REPLICA_HOST"
    echo "disable server postgres_cluster/primary" | socat stdio "$HAPROXY_SOCKET" || true
    echo "set server postgres_cluster/primary addr ${ADDR} port 5432" | socat stdio "$HAPROXY_SOCKET" || true
    echo "enable server postgres_cluster/primary" | socat stdio "$HAPROXY_SOCKET" || true
    log "HAProxy actualizado para usar ${REPLICA_HOST} como primary"
  else
    log "Socket de HAProxy no encontrado; omitir recarga"
  fi
}

while true; do
  if check_primary; then
    sleep "$CHECK_INTERVAL"; continue
  fi
  log "Primario ${PRIMARY_HOST} no responde. Intentando promover replica";
  promote_replica || log "Promocion fallo"
  sleep "$CHECK_INTERVAL"
done
