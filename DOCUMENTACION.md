# Documentación Única del Proyecto 3 – Sistemas Distribuidos

**Curso:** Sistemas Distribuidos  
**Profesor:** Rodrigo Pavez  
**Integrantes:** Rafael Gonzalez, Victor Cornejo, Javier Gamboa  
**Fecha:** 03-12-2025

## 1. Arquitectura
- **Apps**: App1 Inventario (FastAPI/Python, MariaDB), App2 Órdenes (Node/Express, PostgreSQL), App3 Reportes (FastAPI/Python, MySQL).
- **Middleware**: FastAPI, expone `/orders`; reintenta contra instancias A/B de App1/App2 y compensa stock en errores.
- **Bases**: Primario+réplica por motor, HAProxy como entrypoint y watchdogs que promueven la réplica y reconfiguran HAProxy.
- **Load Balancer**: Nginx (`load-balancer`) expone `/` (middleware), `/app1`, `/app2`, `/app3`.
- **Política de restart**: `restart: unless-stopped` en App1/App2 para reanudarse tras pérdida de BD.

## 2. Componentes clave
- `docker-compose.yml`: servicios de apps, bases, HAProxy, watchdogs, balanceador, restart.
- **Watchdogs**:
  - MariaDB: `orchestrator/watchdogs/mariadb/watchdog.sh`
  - PostgreSQL: `orchestrator/watchdogs/postgres/watchdog.sh`
  - MySQL: `orchestrator/watchdogs/mysql/watchdog.sh`
- **Apps**:
  - App1 (`app1-inventario/src/main.py`): `/products`, increment/decrement con fallback DB primario/réplica.
  - App2 (`app2-ordenes/src/index.js`): `/orders` (INSERT).
  - App3 (`app3-reportes/src/main.py`): `/reports` (INSERT).
  - Middleware (`middleware/main.py`): orquesta `/orders` (App1→App2→App3) con compensaciones.

## 3. SLA/SLO
- Disponibilidad mensual ≥ 99.9% para `/orders`, `/products`, `/reports` (excluye mantenimiento).
- Latencia (red local): `/orders` p95 ≤ 350 ms, p99 ≤ 700 ms; endpoints individuales ≤ 300 ms p95.
- Continuidad: caída de un nodo de app o BD no interrumpe operación (HAProxy + watchdog + fallback).
- Integridad: pérdida de datos permitida = 0 para órdenes/reportes en failover.

## 4. Evidencias de tolerancia a fallos
- Ubicación: `tests/evidencias/`
  - MySQL: `*mysql*.txt` (primario caído, POST `/orders` 200).
  - MariaDB: `*mariadb*.txt` (primario caído, POST `/orders` 200).
  - PostgreSQL: `*postgres*.txt` (primario caído, POST `/orders` 200 tras levantar App2).
- Playbook de recuperación: `PRUEBAS.md` (reintegrar primario o recrear volúmenes y levantar primario+réplica+HAProxy+watchdog).

## 5. Métricas de latencia
- Archivo: `tests/latency_orders.txt`
- Comando: `docker run --rm --network proy_unidad3_sistdistribuidos_backend-net williamyeh/hey -H "Content-Type: application/json" -z 15s -c 10 -m POST -d '{"product_id":1,"qty":1}' http://middleware:8000/orders`
- Resultados (stock suficiente, respuestas 422 por validación):
  - p50 ~6.9 ms, p90 ~11.7 ms, p95 ~14.0 ms, p99 ~20.0 ms, RPS ~1242.
  - Dentro del SLO de latencia; si se requiere código 200, repetir el comando (stock ya en 1000) y agregar al mismo archivo.

## 6. Rutas y health
- Middleware: `http://localhost:8000/orders`, health `http://localhost:8000/health`.
- LB: `http://localhost:8080/` y `/app1/health`, `/app2/health`, `/app3/health`.
- App3 directa: `http://localhost:8003/health`.

## 7. Notas finales
- Stock ajustado: `products.id=1` en MariaDB con stock 1000.
- Órdenes/reportes limpiados en últimas pruebas para evitar ruido.
- `restart: unless-stopped` ya aplicado a App1/App2 en `docker-compose.yml`.
