# Evidencias de pruebas

- Failover MySQL: `tests/evidencias/*mysql*.txt` (primario caído, POST `/orders` con 200).
- Failover MariaDB: `tests/evidencias/*mariadb*.txt` (primario caído, POST `/orders` con 200).
- Failover PostgreSQL: `tests/evidencias/*postgres*.txt` (primario caído, POST `/orders` con 200 tras levantar App2).
- Latencia `/orders` (hey 15s, 10c): ver `tests/latency_orders.txt` (p95~10–14 ms, p99~17–20 ms, códigos 422 por validación; repetir con payload válido si se requiere 200).
- Nota: las apps App1/App2 tienen `restart: unless-stopped` en `docker-compose.yml` para reiniciarse tras caída de BD.
