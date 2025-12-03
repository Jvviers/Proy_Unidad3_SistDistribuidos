# Pruebas de tolerancia a fallos

## 1) Caida de servidor de aplicacion primario
- Parar `app1-instance-a` y `app2-instance-a` (`docker compose stop app1-instance-a app2-instance-a`).
- Enviar `POST /orders` al middleware: deberia responder 200 usando replicas B.
- Revisar logs del middleware por reintento y que Nginx/HAProxy sigan en verde.

## 2) Caida de base de datos primaria
- Parar `mariadb-primary` y `postgres-primary` (`docker compose stop mariadb-primary postgres-primary`).
- Repetir `POST /orders`; App1 y App2 deben seguir operando via `mariadb-haproxy`/`postgres-haproxy` hacia replicas.
- Parar `mysql-primary` y crear reporte a traves del middleware: HAProxy debe dirigir a `mysql-replica` y el watchdog debe promoverla (logs en `mysql-watchdog`).

## 3) Caida del middleware
- Parar `middleware`; Nginx debe responder 502. Reiniciar `middleware` y confirmar `/health` OK.

## 4) Integridad de datos
- Verificar que `products.stock` decrementa/incrementa correctamente y que `orders` y `reports` tengan registros consistentes despues de failover.

## 5) Latencia
- Medir p95/p99 de `POST /orders` bajo carga moderada (ej: `hey` o `ab` dentro de red interna) y comparar con SLO definidos.

## 6) Recuperacion post-failover (playbook manual)
- Una vez promovida una replica, el antiguo primario queda desalineado. Para reingresarlo como replica: `docker compose stop <old-primary>`; borrar sus datos (`docker volume rm <primary_data_volume>`), volver a levantarlo para que arranque limpio y reconfigure replicacion desde el nuevo primario siguiendo el script de replica correspondiente.
- Confirmar `read_only`/`super_read_only` en replicas antes del failover (`SHOW VARIABLES LIKE 'read_only';`) y que se desactiva tras la promoción (se coloca en 0).

## 7) Guía rápida para prueba de fallo MySQL (App3)
- Salud previa (confirma servicios arriba): `curl http://localhost:8000/health` y `curl http://localhost:8003/health`.
- Caída del primario (simula fallo de DB): `docker compose stop mysql-primary`. -> Esperar 20-30s.
- Luego `docker compose exec mysql-replica mysqladmin ping -uroot -proot` hasta OK
- Solicitud de orden (valida continuidad): `Invoke-RestMethod -Method Post -Uri http://localhost:8000/orders -Body '{"product_id":1,"qty":1}' -ContentType 'application/json'` → 200 esperado usando la réplica promovida.
- Logs de failover (evidencia del cambio): `docker compose logs --tail=200 mysql-watchdog mysql-haproxy`.
- Volver a estado sano (recrear primario/réplica limpios): 
Para la prueba de fallo MySQL ahora:

`docker compose stop mysql-replica mysql-primary mysql-watchdog mysql-haproxy`

`docker compose rm -f mysql-primary mysql-replica mysql-haproxy mysql-watchdog`

`docker volume rm proy_unidad3_sistdistribuidos_mysql_primary_data proy_unidad3_sistdistribuidos_mysql_replica_data` 

`docker compose up -d mysql-primary mysql-replica mysql-haproxy mysql-watchdog`

## 8) Guía rápida para prueba de fallo MariaDB (App1)
- Salud previa: `curl http://localhost:8000/health` y `curl http://localhost:8080/app1/health` (vía LB).
- Caída del primario: `docker compose stop mariadb-primary`. -> Esperar 20-30s.
- Luego `docker compose exec mariadb-replica mysqladmin ping -uroot -proot` hasta OK
- Solicitud de orden (pasa por App1 para stock): mismo `Invoke-RestMethod` de arriba → debe responder 200 usando la réplica (HAProxy + watchdog).
- Logs de failover: `docker compose logs --tail=200 mariadb-watchdog mariadb-haproxy`.
- Volver a estado sano: 

`docker compose stop mariadb-replica mariadb-primary mariadb-watchdog mariadb-haproxy` 

`docker compose rm -f mariadb-primary mariadb-replica mariadb-haproxy mariadb-watchdog`

`docker volume rm proy_unidad3_sistdistribuidos_mariadb_primary_data proy_unidad3_sistdistribuidos_mariadb_replica_data` 

`docker compose up -d mariadb-primary mariadb-replica mariadb-haproxy mariadb-watchdog`

## 9) Guía rápida para prueba de fallo PostgreSQL (App2)
- Salud previa: `curl http://localhost:8000/health` y `curl http://localhost:8080/app2/health`.
- Caída del primario: `docker compose stop postgres-primary`. -> Esperar 20-30S
- Levantar App1 / App2 porque no tiene restart: `docker compose exec postgres-replica pg_isready -h postgres-replica -U orders -d ordersdb<`
- Luego `docker compose exec postgres-replica pg_isready -h postgres-replica -U orders -d ordersdb` hasta OK
- Solicitud de orden (toca App2/DB): usar el mismo `Invoke-RestMethod` → debe responder 200 con orden creada en la réplica promovida.
- Logs de failover: `docker compose logs --tail=200 postgres-watchdog postgres-haproxy`.
- Volver a estado sano: 

`docker compose stop postgres-replica postgres-primary postgres-watchdog postgres-haproxy` 

`docker compose rm -f postgres-primary postgres-replica postgres-haproxy postgres-watchdog`

`docker volume rm proy_unidad3_sistdistribuidos_postgres_primary_data proy_unidad3_sistdistribuidos_postgres_replica_data`  

`docker compose up -d postgres-primary postgres-replica postgres-haproxy postgres-watchdog`
