# SLA y SLO del Proyecto Distribuido

## Alcance
Servicios: Middleware (FastAPI), App1 Inventario (FastAPI), App2 Ordenes (Node/Express), App3 Reportes (FastAPI), BDs MariaDB/PostgreSQL/MySQL con HAProxy para failover.

## Objetivos de Nivel de Servicio (SLO)
- Disponibilidad mensual: >= 99.9% para endpoints `/orders`, `/products`, `/reports`, excluyendo ventanas de mantenimiento comunicadas con 48h.
- Latencia (en red local del cluster):
  - `POST /orders` (middleware): p95 <= 350 ms, p99 <= 700 ms.
  - `GET /products` (App1): p95 <= 250 ms.
  - `POST /orders` (App2): p95 <= 300 ms.
  - `POST /reports` (App3): p95 <= 300 ms.
- Continuidad y replicacion:
  - Fallo de un nodo de aplicacion o BD no debe interrumpir la operacion (HAProxy conmuta a replica; middleware reintenta contra replica de app1/app2).
  - Replicacion de datos >= 1 replica por motor (MariaDB, PostgreSQL, MySQL) con reintentos de conexion.
- Integridad/p&eacute;rdida de datos: perdida permitida 0 en operaciones de `orders` y `reports` bajo failover.
- Escalabilidad: soportar 3x carga base agregando replicas de app1/app2 y replicas de BD sin cambios de codigo.

## Acuerdos de Nivel de Servicio (SLA)
- Disponibilidad garantizada: 99.5% mensual (penalizacion si cae debajo de 99.9% segun ejemplo adjunto; referencia `EjemploSLAySLO.pdf`).
- Ventanas de mantenimiento: hasta 2 al mes, max 60 minutos, notificadas con 48h.
- Soporte: atencion 24/7 para incidentes P1; respuesta inicial P1 <= 15 min, P2 <= 1h.

## Monitoreo y medicion
- Healthchecks de contenedores (`/health`) y HAProxy con `tcp-check` para primario/replica de BD.
- Logs de eventos de failover en middleware (detalles 502) y en HAProxy (stdout).
- Reporte mensual de uptime y latencia a partir de logs/monitoreo.

## Pruebas de tolerancia a fallos
- Caida de app primaria (app1-instance-a/app2-instance-a): detener contenedor y verificar que middleware siga operando via fallback a instancia B.
- Caida de BD primaria (mariadb-primary/postgres-primary/mysql-primary): detener contenedor, validar que HAProxy rote a replica y que las apps sigan leyendo/escribiendo.
- Caida del middleware: detener contenedor, reiniciar y verificar que healthcheck lo re-incorpore.
- Validar integridad de datos post-failover: contar ordenes/reportes y stocks sin perdida.