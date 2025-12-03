# Informe Proyecto 3 – Sistemas Distribuidos

## 1. Resumen
- Arquitectura de 3 aplicaciones: App1 Inventario (FastAPI/Python, MariaDB), App2 Órdenes (Node/Express, PostgreSQL), App3 Reportes (FastAPI/Python, MySQL).
- Middleware (FastAPI) expone `/orders` y orquesta stock (App1), creación de orden (App2) y reporte (App3) con fallback primario/backup.
- HAProxy por motor (MariaDB/PostgreSQL/MySQL) con primario+réplica y watchdogs que promueven la réplica y reconfiguran HAProxy. Nginx expone `/` (middleware) y `/app1`, `/app2`, `/app3`.

## 2. Configuración técnica
- `docker-compose.yml`: servicios de apps, bases, HAProxy, watchdogs; `restart: unless-stopped` en App1/App2.
- Bases de datos:
  - MariaDB: primario+réplica (binlog, read_only), watchdog `orchestrator/watchdogs/mariadb/watchdog.sh`.
  - PostgreSQL: primario+réplica (pg_basebackup, pg_promote), watchdog `orchestrator/watchdogs/postgres/watchdog.sh`.
  - MySQL: primario+réplica (dump inicial, read_only), watchdog `orchestrator/watchdogs/mysql/watchdog.sh` (con `MYSQL_DATABASE/USER/PASSWORD` en réplica para copiar la tabla `reports`).
- Aplicaciones:
  - App1 (`app1-inventario`): FastAPI, endpoints `/products`, increment/decrement con fallback a réplica DB.
  - App2 (`app2-ordenes`): Node/Express, endpoint `/orders` (INSERT).
  - App3 (`app3-reportes`): FastAPI, endpoint `/reports` (INSERT).
  - Middleware: `/orders` → decrementa stock (App1), crea orden (App2), crea reporte (App3) con compensación de stock en errores.
- Balanceador Nginx: upstream a middleware y apps (`load-balancer/nginx.conf`).

## 3. SLA/SLO
- Disponibilidad mensual ≥ 99.9% para `/orders`, `/products`, `/reports` (excluye mantenimiento).
- Latencia (red local): `/orders` p95 ≤ 350 ms, p99 ≤ 700 ms; endpoints individuales ≤ 300 ms p95.
- Continuidad: caída de un nodo de app o BD no interrumpe operación (HAProxy + watchdog + fallback middleware).
- Integridad: pérdida de datos permitida = 0 para órdenes/reportes en failover.

## 4. Pruebas de tolerancia a fallos (evidencias)
- MySQL (App3): primario detenido, réplica promovida, `POST /orders` 200. Logs en `tests/evidencias/*mysql*.txt` (ej: orden id=2, stock 18, reporte OK).
- MariaDB (App1): primario detenido, `POST /orders` 200 (stock 17). Logs en `tests/evidencias/*mariadb*.txt`.
- PostgreSQL (App2): primario detenido, se levanta App2, `POST /orders` 200 (orden id=4). Logs en `tests/evidencias/*postgres*.txt`.
- Health: middleware y app3 responden 200 en `/health`; LB en `http://localhost:8080/app1|app2|app3/health` tras levantar servicios.
- Playbook de recuperación (ver `PRUEBAS.md`): reintegrar primario tras failover o recrear volúmenes y levantar primario+réplica+HAProxy+watchdog.

## 5. Hallazgos y correcciones
- MySQL: faltaban vars en réplica; se añadieron `MYSQL_DATABASE/USER/PASSWORD` y se verificó replicación de tabla `reports`.
- App2 sin auto-restart: se añadió `restart: unless-stopped` para que se levante tras caída de BD.
- Evidencias separadas por motor en `tests/evidencias`.

## 6. Próximos pasos
- Medir latencia vs SLO (ej. `hey -n 200 -c 10 http://localhost:8000/orders`) y documentar resultados.
- Validar integridad post-failover (stock, órdenes, reportes coherentes) y anotar en el informe.
- Referenciar en el informe los archivos de evidencia y logs; opcional limpiar/renombrar evidencias finales.

## 7. Rutas útiles
- Middleware: `http://localhost:8000/orders`
- LB: `http://localhost:8080/` (middleware), `/app1/health`, `/app2/health`, `/app3/health`
- Health locales: `http://localhost:8000/health`, `http://localhost:8003/health`

## 8. Evidencias y métricas
- Failover:
  - MySQL: `tests/evidencias/*mysql*.txt` (POST 200 con primario caído).
  - MariaDB: `tests/evidencias/*mariadb*.txt` (POST 200 con primario caído).
  - PostgreSQL: `tests/evidencias/*postgres*.txt` (POST 200 con primario caído tras levantar App2).
- Latencia (15s, 10 concurrentes, `hey`):
  - `/orders` vía middleware: p95 ≈ 10–14 ms, p99 ≈ 17–20 ms (ver `tests/latency_orders.txt`); códigos 422 por validación, pero latencias dentro de SLO. Repetir con payload válido si se requiere 200.
- Restart policy: `restart: unless-stopped` en App1/App2 para reinicio automático tras pérdida de BD.
