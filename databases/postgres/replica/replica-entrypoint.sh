#!/bin/bash
set -e

echo 'Limpiando datos previos en la replica...'
rm -rf /var/lib/postgresql/data/*

until pg_isready -h postgres-primary -p 5432 -U replicator; do
  echo 'Esperando al primario PostgreSQL...'
  sleep 2
done

echo 'Ejecutando pg_basebackup desde el primario...'
PGPASSWORD='replpass' pg_basebackup \
  -h postgres-primary \
  -D /var/lib/postgresql/data \
  -U replicator \
  -vP \
  -R

