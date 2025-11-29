# Proyecto Sistemas Distribuidos

## Servicios
- Balanceador NGINX (`localhost:8080`)
- Middleware (`localhost:8000` o vía LB `/middleware/`)
- App1 Inventario (FastAPI) vía LB `/app1/`
- App2 Órdenes (Node) vía LB `/app2/`
- App3 Reportes (FastAPI) vía puerto 8003 o LB `/app3/`
- Bases de datos con réplica: MariaDB (app1), PostgreSQL (app2), MySQL (app3)

## Levantar
```
docker-compose up -d
```

## Prueba end-to-end
1. Crear orden vía middleware:
```
curl -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id":1,"qty":2}'
```
2. Verificar:
```
curl http://localhost:8080/app1/products        # stock decrementado
curl http://localhost:8080/app2/orders          # orden creada
curl http://localhost:8003/reports              # reporte agregado
```

## Healthchecks
- `http://localhost:8080/app1/health`
- `http://localhost:8080/app2/health`
- `http://localhost:8003/health`
- `http://localhost:8000/health`

## Replicación (comandos dentro de contenedores)
- MariaDB réplica:
```
docker exec -it proy_unidad3_sistdistribuidos-mariadb-replica-1 \
  mysql -uroot -proot -e "SHOW SLAVE STATUS\G"
```
- MySQL réplica:
```
docker exec -it proy_unidad3_sistdistribuidos-mysql-replica-1 \
  mysql -uroot -proot -e "SHOW REPLICA STATUS\G"
```
- PostgreSQL:
```
docker exec -it proy_unidad3_sistdistribuidos-postgres-primary-1 \
  psql -U orders -d ordersdb -c "SELECT client_addr,state,sent_lsn,write_lsn,replay_lsn FROM pg_stat_replication;"
docker exec -it proy_unidad3_sistdistribuidos-postgres-replica-1 \
  psql -U replicator -d ordersdb -c "SELECT status, conninfo FROM pg_stat_wal_receiver;"
```

## Rutas principales
- LB `/app1/*`, `/app2/*`, `/app3/*`, `/middleware/*`
- App1: `GET /products`, `POST /products`, `POST /products/{id}/decrement`, `POST /products/{id}/increment`
- App2: `GET /orders`, `POST /orders`, `POST /orders/:id/status`
- App3: `GET /reports`, `POST /reports`
- Middleware: `POST /orders` (orquesta stock, orden y reporte)
